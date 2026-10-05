import Foundation

public struct TelegramBotConfiguration: Equatable, Sendable {
    public let token: String
    public let chatID: String

    public init(token: String, chatID: String) throws {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChatID = chatID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard TelegramBotConfiguration.isValidToken(trimmedToken) else {
            throw TelegramBotConnectorError.invalidToken
        }
        guard TelegramBotConfiguration.isValidChatID(trimmedChatID) else {
            throw TelegramBotConnectorError.invalidChatID
        }
        self.token = trimmedToken
        self.chatID = trimmedChatID
    }

    private static func isValidToken(_ value: String) -> Bool {
        guard value.count >= 20, value.count <= 256, !value.contains("/") else { return false }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].allSatisfy(\.isNumber) else { return false }
        return parts[1].allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    private static func isValidChatID(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 128 else { return false }
        if value.first == "@" {
            return value.dropFirst().count >= 5 && value.dropFirst().allSatisfy {
                $0.isLetter || $0.isNumber || $0 == "_"
            }
        }
        let numeric = value.first == "-" ? value.dropFirst() : Substring(value)
        return !numeric.isEmpty && numeric.allSatisfy(\.isNumber)
    }
}

public enum TelegramBotConnectorError: Error, Equatable, Sendable {
    case invalidToken
    case invalidChatID
    case invalidResponse
    case requestTimedOut
    case transportFailure
    case apiFailure(code: Int, description: String)
    case rateLimited(retryAfter: TimeInterval)
}

extension TelegramBotConnectorError {
    var isDefinitiveRejection: Bool {
        switch self {
        case .invalidToken, .invalidChatID, .apiFailure, .rateLimited:
            return true
        case .invalidResponse, .requestTimedOut, .transportFailure:
            return false
        }
    }
}

public struct TelegramBotHTTPResponse: Equatable, Sendable {
    public let statusCode: Int
    public let data: Data

    public init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.data = data
    }
}

public protocol TelegramBotTransport: AnyObject {
    func execute(_ request: URLRequest) throws -> TelegramBotHTTPResponse
}

public final class URLSessionTelegramBotTransport: TelegramBotTransport {
    private let session: URLSession
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 15) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        self.session = URLSession(
            configuration: configuration,
            delegate: TelegramBotRedirectBlocker(),
            delegateQueue: nil
        )
        self.timeout = timeout
    }

    public func execute(_ request: URLRequest) throws -> TelegramBotHTTPResponse {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<TelegramBotHTTPResponse, Error>?
        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if error != nil {
                result = .failure(TelegramBotConnectorError.transportFailure)
                return
            }
            guard let response = response as? HTTPURLResponse, let data else {
                result = .failure(TelegramBotConnectorError.invalidResponse)
                return
            }
            result = .success(TelegramBotHTTPResponse(statusCode: response.statusCode, data: data))
        }
        task.resume()
        guard semaphore.wait(timeout: .now() + timeout + 1) == .success else {
            task.cancel()
            throw TelegramBotConnectorError.requestTimedOut
        }
        guard let result else { throw TelegramBotConnectorError.invalidResponse }
        return try result.get()
    }
}

private final class TelegramBotRedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

public final class TelegramBotConnector: MessageForwardingConnector {
    private struct APIResponse: Decodable {
        struct Parameters: Decodable {
            let retryAfter: Int?

            enum CodingKeys: String, CodingKey {
                case retryAfter = "retry_after"
            }
        }

        let ok: Bool
        let errorCode: Int?
        let description: String?
        let parameters: Parameters?
        let result: SentMessage?

        struct SentMessage: Decodable {
            let messageID: Int64
            enum CodingKeys: String, CodingKey { case messageID = "message_id" }
        }

        enum CodingKeys: String, CodingKey {
            case ok
            case errorCode = "error_code"
            case description
            case parameters, result
        }
    }

    private let configuration: TelegramBotConfiguration
    private let transport: any TelegramBotTransport
    private let formatter: TelegramBotMessageFormatter
    private let replyRouteStore: (any TelegramReplyRouteStoring)?

    public init(
        configuration: TelegramBotConfiguration,
        transport: any TelegramBotTransport = URLSessionTelegramBotTransport(),
        formatter: TelegramBotMessageFormatter = TelegramBotMessageFormatter(),
        replyRouteStore: (any TelegramReplyRouteStoring)? = nil
    ) {
        self.configuration = configuration
        self.transport = transport
        self.formatter = formatter
        self.replyRouteStore = replyRouteStore
    }

    public func verifyDelivery() throws {
        _ = try send(text: formatter.testMessage())
    }

    public func deliver(_ envelope: MessageConnectorEnvelope) throws -> MessageDeliveryOutcome {
        let messageID = try send(text: formatter.message(for: envelope))
        if let recipientHandle = envelope.senderLabel,
           !recipientHandle.isEmpty,
           let replyRouteStore {
            try replyRouteStore.save(TelegramReplyRoute(
                telegramChatID: configuration.chatID,
                telegramMessageID: messageID,
                recipientHandle: recipientHandle
            ))
        }
        return .delivered
    }

    private func send(text: String) throws -> Int64 {
        let endpoint = "https://api.telegram.org/bot\(configuration.token)/sendMessage"
        guard let url = URL(string: endpoint), url.scheme == "https", url.host == "api.telegram.org" else {
            throw TelegramBotConnectorError.invalidToken
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "chat_id": configuration.chatID,
            "text": text,
            "disable_web_page_preview": true,
        ])

        let response = try transport.execute(request)
        guard let payload = try? JSONDecoder().decode(APIResponse.self, from: response.data) else {
            throw TelegramBotConnectorError.invalidResponse
        }
        if payload.ok, (200..<300).contains(response.statusCode) {
            guard let messageID = payload.result?.messageID else {
                throw TelegramBotConnectorError.invalidResponse
            }
            return messageID
        }
        if response.statusCode == 429 || payload.errorCode == 429 {
            throw TelegramBotConnectorError.rateLimited(
                retryAfter: TimeInterval(payload.parameters?.retryAfter ?? 60)
            )
        }
        throw TelegramBotConnectorError.apiFailure(
            code: payload.errorCode ?? response.statusCode,
            description: payload.description ?? "Telegram request failed"
        )
    }
}

public struct TelegramBotMessageFormatter: Equatable, Sendable {
    public let maximumLength: Int

    public init(maximumLength: Int = 4_096) {
        self.maximumLength = max(128, min(maximumLength, 4_096))
    }

    public func testMessage() -> String {
        "ShareSync Telegram forwarding is ready."
    }

    public func message(for envelope: MessageConnectorEnvelope) -> String {
        var lines = ["ShareSync · iMessage"]
        if let sender = envelope.senderLabel, !sender.isEmpty {
            lines.append("From: \(sender)")
        }
        lines.append("Received: \(envelope.timestamp.formatted(.iso8601))")
        if let body = envelope.body, !body.isEmpty {
            lines.append("")
            lines.append(body)
        }
        if envelope.attachmentCount > 0 {
            let types = envelope.attachmentMIMETypes.sorted().joined(separator: ", ")
            let suffix = types.isEmpty ? "" : " (\(types))"
            lines.append("")
            lines.append("Attachments: \(envelope.attachmentCount)\(suffix)")
        } else if envelope.hasAttachments {
            lines.append("")
            lines.append("Attachment not forwarded by ShareSync privacy settings")
        }
        return truncate(lines.joined(separator: "\n"))
    }

    private func truncate(_ text: String) -> String {
        guard text.count > maximumLength else { return text }
        let marker = "\n…"
        return String(text.prefix(maximumLength - marker.count)) + marker
    }
}
