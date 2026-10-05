import XCTest
@testable import ShareSyncMessageBridge

final class TelegramReplyBridgeTests: XCTestCase {
    func testProcessorSendsOnlyAuthorizedReplyWithKnownLocalRoute() throws {
        let routeStore = MemoryRouteStore()
        try routeStore.save(TelegramReplyRoute(
            telegramChatID: "42",
            telegramMessageID: 700,
            recipientHandle: "+886912345678"
        ))
        let fetcher = FixedUpdateFetcher(updates: [
            TelegramBotUpdate(
                updateID: 10,
                messageID: 800,
                chatID: "42",
                senderUserID: "42",
                text: "reply",
                replyToMessageID: 700
            ),
            TelegramBotUpdate(
                updateID: 11,
                messageID: 801,
                chatID: "42",
                senderUserID: "99",
                text: "blocked",
                replyToMessageID: 700
            ),
        ])
        let cursor = MemoryUpdateCursor()
        let sender = RecordingReplySender()
        let processor = TelegramReplyProcessor(
            updates: fetcher,
            cursorStore: cursor,
            routeStore: routeStore,
            sender: sender,
            authorizedPrivateChatID: "42"
        )

        let result = try processor.run()

        XCTAssertEqual(sender.messages, [.init(text: "reply", handle: "+886912345678")])
        XCTAssertEqual(result.sentCount, 1)
        XCTAssertEqual(result.ignoredCount, 1)
        XCTAssertEqual(result.unconfirmedCount, 0)
        XCTAssertEqual(try cursor.load(), 12)
    }

    func testProcessorRequiresReplyToForwardedTelegramMessage() throws {
        let fetcher = FixedUpdateFetcher(updates: [
            TelegramBotUpdate(
                updateID: 3,
                messageID: 8,
                chatID: "42",
                senderUserID: "42",
                text: "arbitrary command",
                replyToMessageID: nil
            ),
        ])
        let cursor = MemoryUpdateCursor()
        let sender = RecordingReplySender()
        let result = try TelegramReplyProcessor(
            updates: fetcher,
            cursorStore: cursor,
            routeStore: MemoryRouteStore(),
            sender: sender,
            authorizedPrivateChatID: "42"
        ).run()

        XCTAssertTrue(sender.messages.isEmpty)
        XCTAssertEqual(result.ignoredCount, 1)
        XCTAssertEqual(try cursor.load(), 4)
    }

    func testProcessorIgnoresStaleUpdateWithoutMovingCursorBackward() throws {
        let cursor = MemoryUpdateCursor()
        try cursor.save(10)
        let sender = RecordingReplySender()
        let result = try TelegramReplyProcessor(
            updates: FixedBatchFetcher(batch: TelegramBotUpdateBatch(
                updates: [
                    TelegramBotUpdate(
                        updateID: 9,
                        messageID: 8,
                        chatID: "42",
                        senderUserID: "42",
                        text: "stale",
                        replyToMessageID: 7
                    ),
                ],
                nextOffset: 10
            )),
            cursorStore: cursor,
            routeStore: MemoryRouteStore(),
            sender: sender,
            authorizedPrivateChatID: "42"
        ).run()

        XCTAssertEqual(result.ignoredCount, 1)
        XCTAssertTrue(sender.messages.isEmpty)
        XCTAssertEqual(try cursor.load(), 10)
    }

    func testSendFailureDoesNotAdvanceCursor() throws {
        let routeStore = MemoryRouteStore()
        try routeStore.save(TelegramReplyRoute(
            telegramChatID: "42",
            telegramMessageID: 7,
            recipientHandle: "person@example.com"
        ))
        let cursor = MemoryUpdateCursor()
        let sender = RecordingReplySender(shouldFail: true)
        let fetcher = FixedUpdateFetcher(updates: [
            TelegramBotUpdate(
                updateID: 5,
                messageID: 8,
                chatID: "42",
                senderUserID: "42",
                text: "retry me",
                replyToMessageID: 7
            ),
        ])
        let ledger = InMemoryMessageDeliveryLedgerStore()
        let update = fetcher.updates[0]

        XCTAssertThrowsError(try TelegramReplyProcessor(
            updates: fetcher,
            cursorStore: cursor,
            routeStore: routeStore,
            sender: sender,
            authorizedPrivateChatID: "42",
            deliveryLedger: ledger
        ).run())
        XCTAssertEqual(try cursor.load(), 0)
        XCTAssertNil(try ledger.record(for: TelegramReplyProcessor.deliveryKey(for: update)))
    }

    func testAmbiguousSendFailureKeepsPendingAndPreventsResend() throws {
        let routeStore = MemoryRouteStore()
        try routeStore.save(TelegramReplyRoute(
            telegramChatID: "42",
            telegramMessageID: 7,
            recipientHandle: "person@example.com"
        ))
        let update = TelegramBotUpdate(
            updateID: 5,
            messageID: 8,
            chatID: "42",
            senderUserID: "42",
            text: "send once",
            replyToMessageID: 7
        )
        let cursor = MemoryUpdateCursor()
        let sender = AmbiguousReplySender()
        let ledger = InMemoryMessageDeliveryLedgerStore()
        let processor = TelegramReplyProcessor(
            updates: FixedUpdateFetcher(updates: [update]),
            cursorStore: cursor,
            routeStore: routeStore,
            sender: sender,
            authorizedPrivateChatID: "42",
            deliveryLedger: ledger
        )

        XCTAssertThrowsError(try processor.run()) { error in
            XCTAssertEqual(error as? IMessageReplyDeliveryError, .deliveryUnconfirmed)
        }
        XCTAssertEqual(try cursor.load(), 0)
        XCTAssertEqual(sender.attemptCount, 1)
        XCTAssertEqual(
            try ledger.record(for: TelegramReplyProcessor.deliveryKey(for: update))?.state,
            .pending
        )

        let retry = try processor.run()

        XCTAssertEqual(retry.sentCount, 0)
        XCTAssertEqual(retry.ignoredCount, 1)
        XCTAssertEqual(retry.unconfirmedCount, 1)
        XCTAssertEqual(sender.attemptCount, 1)
        XCTAssertEqual(try cursor.load(), 6)
    }

    func testPendingReplyLedgerPreventsAmbiguousResendAndAdvancesCursor() throws {
        let routeStore = MemoryRouteStore()
        try routeStore.save(TelegramReplyRoute(
            telegramChatID: "42",
            telegramMessageID: 7,
            recipientHandle: "person@example.com"
        ))
        let update = TelegramBotUpdate(
            updateID: 5,
            messageID: 8,
            chatID: "42",
            senderUserID: "42",
            text: "do not resend",
            replyToMessageID: 7
        )
        let ledger = InMemoryMessageDeliveryLedgerStore()
        try ledger.markPending(
            deliveryKey: TelegramReplyProcessor.deliveryKey(for: update),
            at: Date(timeIntervalSince1970: 1)
        )
        let cursor = MemoryUpdateCursor()
        let sender = RecordingReplySender()

        let result = try TelegramReplyProcessor(
            updates: FixedUpdateFetcher(updates: [update]),
            cursorStore: cursor,
            routeStore: routeStore,
            sender: sender,
            authorizedPrivateChatID: "42",
            deliveryLedger: ledger
        ).run()

        XCTAssertTrue(sender.messages.isEmpty)
        XCTAssertEqual(result.sentCount, 0)
        XCTAssertEqual(result.ignoredCount, 1)
        XCTAssertEqual(result.unconfirmedCount, 1)
        XCTAssertEqual(try cursor.load(), 6)
    }

    func testBaselineConsumesPendingUpdatesWithoutSending() throws {
        let cursor = MemoryUpdateCursor()
        let sender = RecordingReplySender()
        let fetcher = FixedUpdateFetcher(updates: [
            TelegramBotUpdate(
                updateID: 20,
                messageID: 9,
                chatID: "42",
                senderUserID: "42",
                text: "/start",
                replyToMessageID: nil
            ),
        ])
        let processor = TelegramReplyProcessor(
            updates: fetcher,
            cursorStore: cursor,
            routeStore: MemoryRouteStore(),
            sender: sender,
            authorizedPrivateChatID: "42"
        )

        try processor.establishBaseline()

        XCTAssertEqual(try cursor.load(), 21)
        XCTAssertTrue(sender.messages.isEmpty)
    }

    func testFileStoresPersistRouteAndCursorAndClearThem() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let routeStore = FileTelegramReplyRouteStore(
            fileURL: directory.appendingPathComponent("routes.json")
        )
        let cursorStore = FileTelegramUpdateCursorStore(
            fileURL: directory.appendingPathComponent("cursor.json")
        )
        let route = TelegramReplyRoute(
            telegramChatID: "42",
            telegramMessageID: 700,
            recipientHandle: "person@example.com"
        )

        try routeStore.save(route)
        try cursorStore.save(81)

        XCTAssertEqual(try routeStore.route(chatID: "42", messageID: 700), route)
        XCTAssertEqual(try cursorStore.load(), 81)
        XCTAssertTrue(cursorStore.hasStoredCursor)

        try routeStore.clear()
        try cursorStore.clear()
        XCTAssertNil(try routeStore.route(chatID: "42", messageID: 700))
        XCTAssertFalse(cursorStore.hasStoredCursor)
    }

    func testSeparateRouteStoreInstancesDoNotLoseConcurrentRoutes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("routes.json")
        let stores = (0..<4).map { _ in
            FileTelegramReplyRouteStore(fileURL: fileURL, maximumRoutes: 100)
        }
        let errorLock = NSLock()
        var errors: [Error] = []

        DispatchQueue.concurrentPerform(iterations: 100) { index in
            do {
                try stores[index % stores.count].save(TelegramReplyRoute(
                    telegramChatID: "42",
                    telegramMessageID: Int64(index),
                    recipientHandle: "person-\(index)@example.com"
                ))
            } catch {
                errorLock.lock()
                errors.append(error)
                errorLock.unlock()
            }
        }

        XCTAssertTrue(errors.isEmpty)
        let reader = FileTelegramReplyRouteStore(fileURL: fileURL, maximumRoutes: 100)
        for index in 0..<100 {
            XCTAssertEqual(
                try reader.route(chatID: "42", messageID: Int64(index))?.recipientHandle,
                "person-\(index)@example.com"
            )
        }
    }

    func testExpiredReplyRouteIsRemovedAndCannotBeResolved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("routes.json")
        let now = Date(timeIntervalSince1970: 1_000)
        let initialStore = FileTelegramReplyRouteStore(
            fileURL: fileURL,
            maximumAge: 100,
            now: { Date(timeIntervalSince1970: 500) }
        )
        try initialStore.save(TelegramReplyRoute(
            telegramChatID: "42",
            telegramMessageID: 1,
            recipientHandle: "old@example.com",
            createdAt: Date(timeIntervalSince1970: 500)
        ))
        try initialStore.save(TelegramReplyRoute(
            telegramChatID: "42",
            telegramMessageID: 2,
            recipientHandle: "fresh@example.com",
            createdAt: Date(timeIntervalSince1970: 950)
        ))
        let store = FileTelegramReplyRouteStore(
            fileURL: fileURL,
            maximumAge: 100,
            now: { now }
        )

        XCTAssertNil(try store.route(chatID: "42", messageID: 1))
        XCTAssertEqual(
            try store.route(chatID: "42", messageID: 2)?.recipientHandle,
            "fresh@example.com"
        )
        XCTAssertFalse(try String(contentsOf: fileURL).contains("old@example.com"))
    }

    func testReplyProcessorPrunesDeliveredButRetainsPendingLedgerRecords() throws {
        let ledger = InMemoryMessageDeliveryLedgerStore()
        try ledger.markDelivered(deliveryKey: "expired", at: Date(timeIntervalSince1970: 10))
        try ledger.markPending(deliveryKey: "uncertain", at: Date(timeIntervalSince1970: 10))
        let processor = TelegramReplyProcessor(
            updates: FixedUpdateFetcher(updates: []),
            cursorStore: MemoryUpdateCursor(),
            routeStore: MemoryRouteStore(),
            sender: RecordingReplySender(),
            authorizedPrivateChatID: "42",
            deliveryLedger: ledger,
            deliveredRecordRetention: 100,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        _ = try processor.run()

        XCTAssertNil(try ledger.record(for: "expired"))
        XCTAssertEqual(try ledger.record(for: "uncertain")?.state, .pending)
    }

    func testMalformedReplyStoresReportPersistentStateFailure() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let routeURL = directory.appendingPathComponent("routes.json")
        let cursorURL = directory.appendingPathComponent("cursor.json")
        try Data("invalid".utf8).write(to: routeURL)
        try Data("invalid".utf8).write(to: cursorURL)

        XCTAssertThrowsError(
            try FileTelegramReplyRouteStore(fileURL: routeURL).route(chatID: "42", messageID: 1)
        ) { error in
            XCTAssertTrue(error is MessageBridgePersistentStateFailure)
        }
        XCTAssertThrowsError(
            try FileTelegramUpdateCursorStore(fileURL: cursorURL).load()
        ) { error in
            XCTAssertTrue(error is MessageBridgePersistentStateFailure)
        }
    }

    func testProcessorAdvancesPastUnsupportedTelegramUpdates() throws {
        let cursor = MemoryUpdateCursor()
        let processor = TelegramReplyProcessor(
            updates: FixedBatchFetcher(batch: TelegramBotUpdateBatch(updates: [], nextOffset: 31)),
            cursorStore: cursor,
            routeStore: MemoryRouteStore(),
            sender: RecordingReplySender(),
            authorizedPrivateChatID: "42"
        )

        let result = try processor.run()

        XCTAssertEqual(result.inspectedCount, 0)
        XCTAssertEqual(try cursor.load(), 31)
    }
}

private final class FixedUpdateFetcher: TelegramBotUpdateFetching {
    let updates: [TelegramBotUpdate]
    init(updates: [TelegramBotUpdate]) { self.updates = updates }

    func fetch(after offset: Int64) throws -> TelegramBotUpdateBatch {
        let visible = updates.filter { $0.updateID >= offset }
        return TelegramBotUpdateBatch(
            updates: visible,
            nextOffset: max(offset, (visible.map(\.updateID).max() ?? (offset - 1)) + 1)
        )
    }
}

private final class FixedBatchFetcher: TelegramBotUpdateFetching {
    let batch: TelegramBotUpdateBatch
    init(batch: TelegramBotUpdateBatch) { self.batch = batch }
    func fetch(after offset: Int64) throws -> TelegramBotUpdateBatch { batch }
}

private final class MemoryUpdateCursor: TelegramUpdateCursorStoring {
    private var offset: Int64 = 0
    func load() throws -> Int64 { offset }
    func save(_ offset: Int64) throws { self.offset = offset }
    func clear() throws { offset = 0 }
}

private final class MemoryRouteStore: TelegramReplyRouteStoring {
    private var routes: [String: TelegramReplyRoute] = [:]
    func save(_ route: TelegramReplyRoute) throws {
        routes["\(route.telegramChatID):\(route.telegramMessageID)"] = route
    }
    func route(chatID: String, messageID: Int64) throws -> TelegramReplyRoute? {
        routes["\(chatID):\(messageID)"]
    }
    func clear() throws { routes.removeAll() }
}

private final class RecordingReplySender: IMessageReplySending {
    struct Message: Equatable { let text: String; let handle: String }
    private(set) var messages: [Message] = []
    let shouldFail: Bool
    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }
    func send(text: String, to recipientHandle: String) throws {
        if shouldFail { throw TestError.failed }
        messages.append(.init(text: text, handle: recipientHandle))
    }
    private enum TestError: IMessageReplySendFailure {
        case failed
        var isDefinitiveFailure: Bool { true }
    }
}

private final class AmbiguousReplySender: IMessageReplySending {
    private(set) var attemptCount = 0
    func send(text: String, to recipientHandle: String) throws {
        attemptCount += 1
        throw TestError.failed
    }
    private enum TestError: Error { case failed }
}
