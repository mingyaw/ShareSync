import Foundation

public struct TelegramReplyRoute: Codable, Equatable, Sendable {
    public let telegramChatID: String
    public let telegramMessageID: Int64
    public let recipientHandle: String
    public let createdAt: Date

    public init(
        telegramChatID: String,
        telegramMessageID: Int64,
        recipientHandle: String,
        createdAt: Date = Date()
    ) {
        self.telegramChatID = telegramChatID
        self.telegramMessageID = telegramMessageID
        self.recipientHandle = recipientHandle
        self.createdAt = createdAt
    }
}

public protocol TelegramReplyRouteStoring: AnyObject {
    func save(_ route: TelegramReplyRoute) throws
    func route(chatID: String, messageID: Int64) throws -> TelegramReplyRoute?
    func clear() throws
}

public final class FileTelegramReplyRouteStore: TelegramReplyRouteStoring {
    private struct Envelope: Codable {
        let version: Int
        var routes: [TelegramReplyRoute]
    }

    private let fileURL: URL
    private let maximumRoutes: Int
    private let lock = NSLock()

    public init(fileURL: URL, maximumRoutes: Int = 1_000) {
        self.fileURL = fileURL
        self.maximumRoutes = max(maximumRoutes, 1)
    }

    public func save(_ route: TelegramReplyRoute) throws {
        lock.lock()
        defer { lock.unlock() }
        var envelope = try loadUnlocked()
        envelope.routes.removeAll {
            $0.telegramChatID == route.telegramChatID && $0.telegramMessageID == route.telegramMessageID
        }
        envelope.routes.append(route)
        envelope.routes = Array(envelope.routes.suffix(maximumRoutes))
        try saveUnlocked(envelope)
    }

    public func route(chatID: String, messageID: Int64) throws -> TelegramReplyRoute? {
        lock.lock()
        defer { lock.unlock() }
        return try loadUnlocked().routes.last {
            $0.telegramChatID == chatID && $0.telegramMessageID == messageID
        }
    }

    public func clear() throws {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    private func loadUnlocked() throws -> Envelope {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Envelope(version: 1, routes: [])
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: fileURL))
        guard envelope.version == 1 else { throw TelegramReplyBridgeError.unsupportedState }
        return envelope
    }

    private func saveUnlocked(_ envelope: Envelope) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(envelope).write(to: fileURL, options: .atomic)
    }
}

public struct TelegramBotUpdate: Equatable, Sendable {
    public let updateID: Int64
    public let messageID: Int64
    public let chatID: String
    public let senderUserID: String?
    public let text: String?
    public let replyToMessageID: Int64?
}

public struct TelegramBotUpdateBatch: Equatable, Sendable {
    public let updates: [TelegramBotUpdate]
    public let nextOffset: Int64

    public init(updates: [TelegramBotUpdate], nextOffset: Int64) {
        self.updates = updates
        self.nextOffset = nextOffset
    }
}

public protocol TelegramBotUpdateFetching: AnyObject {
    func fetch(after offset: Int64) throws -> TelegramBotUpdateBatch
}

public final class TelegramBotUpdateClient: TelegramBotUpdateFetching {
    private struct Response: Decodable {
        struct Update: Decodable {
            struct Message: Decodable {
                struct Chat: Decodable { let id: Int64 }
                struct User: Decodable { let id: Int64 }
                let messageID: Int64
                let chat: Chat
                let from: User?
                let text: String?
                let replyToMessage: ReplyMessage?

                enum CodingKeys: String, CodingKey {
                    case messageID = "message_id"
                    case chat, from, text
                    case replyToMessage = "reply_to_message"
                }
            }

            struct ReplyMessage: Decodable {
                let messageID: Int64
                enum CodingKeys: String, CodingKey { case messageID = "message_id" }
            }

            let updateID: Int64
            let message: Message?

            enum CodingKeys: String, CodingKey {
                case updateID = "update_id"
                case message
            }
        }

        let ok: Bool
        let result: [Update]?
        let errorCode: Int?
        let description: String?

        enum CodingKeys: String, CodingKey {
            case ok, result, description
            case errorCode = "error_code"
        }
    }

    private let configuration: TelegramBotConfiguration
    private let transport: any TelegramBotTransport

    public init(
        configuration: TelegramBotConfiguration,
        transport: any TelegramBotTransport = URLSessionTelegramBotTransport()
    ) {
        self.configuration = configuration
        self.transport = transport
    }

    public func fetch(after offset: Int64) throws -> TelegramBotUpdateBatch {
        let endpoint = "https://api.telegram.org/bot\(configuration.token)/getUpdates"
        guard let url = URL(string: endpoint), url.scheme == "https", url.host == "api.telegram.org" else {
            throw TelegramBotConnectorError.invalidToken
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "offset": offset,
            "limit": 100,
            "timeout": 0,
            "allowed_updates": ["message"],
        ])
        let response = try transport.execute(request)
        guard let payload = try? JSONDecoder().decode(Response.self, from: response.data) else {
            throw TelegramBotConnectorError.invalidResponse
        }
        guard payload.ok, (200..<300).contains(response.statusCode) else {
            throw TelegramBotConnectorError.apiFailure(
                code: payload.errorCode ?? response.statusCode,
                description: payload.description ?? "Telegram update request failed"
            )
        }
        let source = payload.result ?? []
        let updates = source.compactMap { update -> TelegramBotUpdate? in
            guard let message = update.message else { return nil }
            return TelegramBotUpdate(
                updateID: update.updateID,
                messageID: message.messageID,
                chatID: String(message.chat.id),
                senderUserID: message.from.map { String($0.id) },
                text: message.text,
                replyToMessageID: message.replyToMessage?.messageID
            )
        }
        let next = max(offset, (source.map(\.updateID).max() ?? (offset - 1)) + 1)
        return TelegramBotUpdateBatch(updates: updates, nextOffset: next)
    }
}

public protocol TelegramUpdateCursorStoring: AnyObject {
    func load() throws -> Int64
    func save(_ offset: Int64) throws
    func clear() throws
}

public final class FileTelegramUpdateCursorStore: TelegramUpdateCursorStoring {
    private struct Envelope: Codable { let version: Int; let offset: Int64 }
    private let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public var hasStoredCursor: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    public func load() throws -> Int64 {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return 0 }
        let value = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: fileURL))
        guard value.version == 1 else { throw TelegramReplyBridgeError.unsupportedState }
        return value.offset
    }

    public func save(_ offset: Int64) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(Envelope(version: 1, offset: offset))
            .write(to: fileURL, options: .atomic)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

public protocol IMessageReplySending: AnyObject {
    func send(text: String, to recipientHandle: String) throws
}

public struct TelegramReplyRunResult: Equatable, Sendable {
    public let inspectedCount: Int
    public let sentCount: Int
    public let ignoredCount: Int
}

public struct TelegramReplyProcessor {
    private let updates: any TelegramBotUpdateFetching
    private let cursorStore: any TelegramUpdateCursorStoring
    private let routeStore: any TelegramReplyRouteStoring
    private let sender: any IMessageReplySending
    private let deliveryLedger: any MessageDeliveryLedgerStore
    private let authorizedPrivateChatID: String
    private let now: () -> Date

    public init(
        updates: any TelegramBotUpdateFetching,
        cursorStore: any TelegramUpdateCursorStoring,
        routeStore: any TelegramReplyRouteStoring,
        sender: any IMessageReplySending,
        authorizedPrivateChatID: String,
        deliveryLedger: any MessageDeliveryLedgerStore = InMemoryMessageDeliveryLedgerStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.updates = updates
        self.cursorStore = cursorStore
        self.routeStore = routeStore
        self.sender = sender
        self.deliveryLedger = deliveryLedger
        self.authorizedPrivateChatID = authorizedPrivateChatID
        self.now = now
    }

    public func establishBaseline() throws {
        let batch = try updates.fetch(after: try cursorStore.load())
        try cursorStore.save(batch.nextOffset)
    }

    public func run() throws -> TelegramReplyRunResult {
        let offset = try cursorStore.load()
        let batch = try updates.fetch(after: offset)
        var sent = 0
        var ignored = 0
        for update in batch.updates.sorted(by: { $0.updateID < $1.updateID }) {
            let nextOffset = update.updateID + 1
            guard update.chatID == authorizedPrivateChatID,
                  update.senderUserID == authorizedPrivateChatID,
                  let replyID = update.replyToMessageID,
                  let text = update.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty,
                  text.count <= 4_000,
                  let route = try routeStore.route(chatID: update.chatID, messageID: replyID) else {
                ignored += 1
                try cursorStore.save(nextOffset)
                continue
            }
            let deliveryKey = Self.deliveryKey(for: update)
            if try deliveryLedger.record(for: deliveryKey) != nil {
                ignored += 1
                try cursorStore.save(nextOffset)
                continue
            }
            try deliveryLedger.markPending(deliveryKey: deliveryKey, at: now())
            do {
                try sender.send(text: text, to: route.recipientHandle)
            } catch {
                try? deliveryLedger.remove(deliveryKey: deliveryKey)
                throw error
            }
            try deliveryLedger.markDelivered(deliveryKey: deliveryKey, at: now())
            sent += 1
            try cursorStore.save(nextOffset)
        }
        let persistedOffset = try cursorStore.load()
        if batch.nextOffset > persistedOffset {
            try cursorStore.save(batch.nextOffset)
        }
        return TelegramReplyRunResult(
            inspectedCount: batch.updates.count,
            sentCount: sent,
            ignoredCount: ignored
        )
    }

    static func deliveryKey(for update: TelegramBotUpdate) -> String {
        "telegram-reply:\(update.chatID):\(update.updateID)"
    }
}

public enum TelegramReplyBridgeError: Error, Equatable {
    case unsupportedState
}
