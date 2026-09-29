import XCTest
@testable import ShareSyncMessageBridge

final class MessageForwardingPipelineTests: XCTestCase {
    func testNormalizerCreatesStableOpaqueDeliveryKeyAndAppleTimestamp() {
        let event = makeEvent(rowID: 7, guid: "private-guid", rawDate: 5_000_000_000_000)
        let normalizer = MessageEventNormalizer()

        let first = normalizer.normalize(event)
        let second = normalizer.normalize(event)

        XCTAssertEqual(first.deliveryKey, second.deliveryKey)
        XCTAssertEqual(first.deliveryKey.count, 64)
        XCTAssertFalse(first.deliveryKey.contains("private-guid"))
        XCTAssertEqual(first.timestamp.timeIntervalSinceReferenceDate, 5_000, accuracy: 0.001)
        XCTAssertEqual(first.contentKinds, [.text])
    }

    func testPolicyFailsClosedForUnknownSenderOutgoingAndAssociatedEvents() {
        let policy = MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"])
        let normalizer = MessageEventNormalizer()

        XCTAssertTrue(policy.permits(normalizer.normalize(makeEvent(sender: "allowed"))))
        XCTAssertFalse(policy.permits(normalizer.normalize(makeEvent(sender: "unknown"))))
        XCTAssertFalse(policy.permits(normalizer.normalize(makeEvent(sender: "allowed", isFromMe: true))))
        XCTAssertFalse(policy.permits(normalizer.normalize(makeEvent(sender: "allowed", associatedType: 2000))))
    }

    func testPolicyCanRestrictAnAllowedSenderToSpecificConversation() {
        let normalizer = MessageEventNormalizer()
        let policy = MessageForwardingPolicy(
            allowedSenderIdentifiers: ["allowed"],
            allowedConversationIdentifiers: ["work-chat"]
        )

        XCTAssertTrue(policy.permits(normalizer.normalize(makeEvent(conversations: ["work-chat"]))))
        XCTAssertFalse(policy.permits(normalizer.normalize(makeEvent(conversations: ["private-chat"]))))
        XCTAssertFalse(policy.permits(normalizer.normalize(makeEvent(conversations: []))))
    }

    func testPolicyBlocksConfiguredSensitiveTermAndLikelyOneTimeCode() {
        let normalizer = MessageEventNormalizer()
        let policy = MessageForwardingPolicy(
            allowedSenderIdentifiers: ["allowed"],
            blockedBodyTerms: ["confidential"]
        )

        XCTAssertEqual(
            policy.evaluate(normalizer.normalize(makeEvent(body: "Confidential plan"))),
            .deny(.sensitiveContent)
        )
        XCTAssertEqual(
            policy.evaluate(normalizer.normalize(makeEvent(body: "Your verification code is 482901"))),
            .deny(.sensitiveContent)
        )
        XCTAssertEqual(
            policy.evaluate(normalizer.normalize(makeEvent(body: "Meeting room 482901"))),
            .allow
        )
    }

    func testPausedPipelineKeepsCursorAndMessagesQueued() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle(identifier: "allowed")
        let store = try makeStore()
        try store.store.save(MessageCursor(rowID: 0))
        try fixture.insertMessage(guid: "queued", body: "one")
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store,
            policy: MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"]),
            connector: InMemoryMessageForwardingConnector(),
            runtimeGate: MessageForwardingRuntimeGate(isPaused: true)
        )

        XCTAssertThrowsError(try pipeline.run()) { error in
            XCTAssertEqual(error as? MessageForwardingRuntimeBlock, .paused)
        }
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 0))
    }

    func testRateLimitKeepsBatchCursorForLaterRetry() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle(identifier: "allowed")
        let store = try makeStore()
        try store.store.save(MessageCursor(rowID: 0))
        try fixture.insertMessage(guid: "first", body: "one")
        try fixture.insertMessage(guid: "second", body: "two")
        let connector = InMemoryMessageForwardingConnector()
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store,
            policy: MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"]),
            connector: connector,
            deliveryLedger: InMemoryMessageDeliveryLedgerStore(),
            rateLimiter: MessageDeliveryRateLimiter(maximumDeliveries: 1, interval: 60),
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        XCTAssertThrowsError(try pipeline.run()) { error in
            XCTAssertEqual(error as? MessageForwardingPipelineError, .rateLimited(retryAfter: 60))
        }
        XCTAssertEqual(connector.deliveries.map(\.sourceGUID), ["first"])
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 0))
    }

    func testPipelineFiltersAndAdvancesPastInspectedRows() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle(identifier: "allowed")
        let store = try makeStore()
        try store.store.save(MessageCursor(rowID: 0))
        try fixture.insertMessage(guid: "accepted", body: "one")
        try fixture.insertMessage(guid: "outgoing", body: "two", isFromMe: true)
        let connector = InMemoryMessageForwardingConnector()
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store,
            policy: MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"]),
            connector: connector
        )

        let result = try pipeline.run()

        XCTAssertEqual(result.inspectedCount, 2)
        XCTAssertEqual(result.eligibleCount, 1)
        XCTAssertEqual(result.deliveredCount, 1)
        XCTAssertEqual(result.deniedCounts, [.outgoingMessage: 1])
        XCTAssertEqual(connector.deliveries.map(\.sourceGUID), ["accepted"])
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 2))
    }

    func testConnectorFailureLeavesCursorForIdempotentRetry() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle(identifier: "allowed")
        let store = try makeStore()
        try store.store.save(MessageCursor(rowID: 0))
        try fixture.insertMessage(guid: "first", body: "one")
        try fixture.insertMessage(guid: "second", body: "two")
        let connector = FailOnceConnector(failingGUID: "second")
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store,
            policy: MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"]),
            connector: connector
        )

        XCTAssertThrowsError(try pipeline.run())
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 0))

        let retry = try pipeline.run()
        XCTAssertEqual(retry.deliveredCount, 1)
        XCTAssertEqual(retry.duplicateCount, 1)
        XCTAssertEqual(connector.deliveredGUIDs, ["first", "second"])
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 2))
    }

    func testPipelineRequiresBaseline() throws {
        let fixture = try MessageBridgeFixture()
        let store = try makeStore()
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store,
            policy: MessageForwardingPolicy(allowedSenderIdentifiers: []),
            connector: InMemoryMessageForwardingConnector()
        )

        XCTAssertThrowsError(try pipeline.run()) { error in
            XCTAssertEqual(error as? MessageValidationSessionError, .baselineRequired)
        }
    }

    private func makeEvent(
        rowID: Int64 = 1,
        guid: String = "guid",
        rawDate: Int64 = 1,
        sender: String? = "allowed",
        isFromMe: Bool = false,
        associatedType: Int64 = 0,
        conversations: [String] = [],
        body: String = "body"
    ) -> MessageEvent {
        MessageEvent(
            rowID: rowID,
            guid: guid,
            body: body,
            rawDate: rawDate,
            isFromMe: isFromMe,
            service: "iMessage",
            hasAttachments: false,
            associatedMessageType: associatedType,
            associatedMessageGUID: nil,
            hasAttributedBody: false,
            senderIdentifier: sender,
            conversationIdentifiers: conversations
        )
    }

    private func makeStore() throws -> (store: FileMessageCursorStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return (FileMessageCursorStore(fileURL: directory.appendingPathComponent("cursor.json")), directory)
    }
}

private final class FailOnceConnector: MessageForwardingConnector {
    private let failingGUID: String
    private var hasFailed = false
    private var deliveredKeys: Set<String> = []
    private(set) var deliveredGUIDs: [String] = []

    init(failingGUID: String) {
        self.failingGUID = failingGUID
    }

    func deliver(_ event: NormalizedMessageEvent) throws -> MessageDeliveryOutcome {
        if event.sourceGUID == failingGUID && !hasFailed {
            hasFailed = true
            throw TestError.failed
        }
        guard deliveredKeys.insert(event.deliveryKey).inserted else { return .duplicate }
        deliveredGUIDs.append(event.sourceGUID)
        return .delivered
    }

    private enum TestError: Error {
        case failed
    }
}
