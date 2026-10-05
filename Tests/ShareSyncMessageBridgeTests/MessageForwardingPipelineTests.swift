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

    func testOutgoingMessageIsClassifiedAsLoopPreventionBeforeSenderChecks() {
        let policy = MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"])
        let event = MessageEventNormalizer().normalize(makeEvent(sender: nil, isFromMe: true))

        XCTAssertEqual(policy.evaluate(event), .deny(.outgoingMessage))
    }

    func testPolicyAllowsEachConfiguredSenderAndRejectsOthers() {
        let policy = MessageForwardingPolicy(allowedSenderIdentifiers: ["first", "second"])
        let normalizer = MessageEventNormalizer()

        XCTAssertTrue(policy.permits(normalizer.normalize(makeEvent(sender: "first"))))
        XCTAssertTrue(policy.permits(normalizer.normalize(makeEvent(sender: "second"))))
        XCTAssertFalse(policy.permits(normalizer.normalize(makeEvent(sender: "third"))))
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

    func testOutsideScheduleKeepsCursorAndMessagesQueued() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle(identifier: "allowed")
        let store = try makeStore()
        try store.store.save(MessageCursor(rowID: 0))
        try fixture.insertMessage(guid: "queued", body: "one")
        let schedule = MessageForwardingSchedule(
            weekdays: [2],
            startMinute: 9 * 60,
            endMinute: 17 * 60,
            timeZoneIdentifier: "Asia/Taipei"
        )
        let outsideWindow = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-09-28T18:00:00+08:00")
        )
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store,
            policy: MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"]),
            connector: InMemoryMessageForwardingConnector(),
            runtimeGate: MessageForwardingRuntimeGate(schedule: schedule),
            now: { outsideWindow }
        )

        XCTAssertThrowsError(try pipeline.run()) { error in
            XCTAssertEqual(error as? MessageForwardingRuntimeBlock, .outsideSchedule)
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
        XCTAssertEqual(connector.deliveries.map(\.body), ["one"])
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
        XCTAssertEqual(result.preventedLoopCount, 1)
        XCTAssertEqual(connector.deliveries.map(\.body), ["one"])
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
        XCTAssertEqual(retry.deliveredAttachmentCount, 0)
        XCTAssertEqual(retry.duplicateAttachmentCount, 0)
        XCTAssertEqual(retry.confirmedAttachmentCount, 0)
        XCTAssertEqual(retry.unconfirmedMessageCount, 0)
        XCTAssertEqual(retry.duplicateCount, 1)
        XCTAssertEqual(connector.deliveredGUIDs, ["first", "second"])
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 2))
    }

    func testAmbiguousTextFailureIsNotResentAndAdvancesOnNextPass() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle(identifier: "allowed")
        try fixture.insertMessage(guid: "ambiguous", body: "one")
        let store = try makeStore()
        try store.store.save(MessageCursor(rowID: 0))
        let connector = AmbiguousFailOnceConnector()
        let ledger = InMemoryMessageDeliveryLedgerStore()
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store,
            policy: MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"]),
            connector: connector,
            deliveryLedger: ledger
        )

        XCTAssertThrowsError(try pipeline.run()) { error in
            XCTAssertEqual(
                error as? MessageForwardingPipelineError,
                .deliveryUnconfirmed
            )
        }
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 0))
        XCTAssertEqual(connector.attemptCount, 1)

        let retry = try pipeline.run()

        XCTAssertEqual(retry.deliveredCount, 0)
        XCTAssertEqual(retry.duplicateCount, 0)
        XCTAssertEqual(retry.unconfirmedMessageCount, 1)
        XCTAssertEqual(connector.attemptCount, 1)
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 1))
        XCTAssertTrue(ledger.records.keys.allSatisfy { $0.count == 64 })
        XCTAssertFalse(ledger.records.keys.contains { $0.contains("ambiguous") })
    }

    func testAmbiguousAttachmentFailureIsNotResentAndAdvancesOnNextPass() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle(identifier: "allowed")
        try fixture.insertMessage(
            guid: "attachment-message",
            body: "photo attached",
            hasAttachments: true
        )
        let attachmentRoot = fixture.directoryURL.appendingPathComponent(
            "Attachments",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: attachmentRoot,
            withIntermediateDirectories: true
        )
        let attachmentURL = attachmentRoot.appendingPathComponent("photo.jpg")
        try Data("image-data".utf8).write(to: attachmentURL)
        try fixture.insertAttachment(
            filename: attachmentURL.path,
            mimeType: "image/jpeg"
        )
        try fixture.linkAttachment(rowID: 1, toMessage: 1)
        let store = try makeStore()
        try store.store.save(MessageCursor(rowID: 0))
        let policy = MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"])
        let mediaConnector = FailOnceAttachmentConnector()
        let ledger = InMemoryMessageDeliveryLedgerStore()
        let textConnector = InMemoryMessageForwardingConnector()
        let attachmentDelivery = MessageAttachmentDeliveryCoordinator(
            accessCoordinator: MessageAttachmentAccessCoordinator(
                forwardingPolicy: policy,
                candidateProvider: SQLiteMessageAttachmentCandidateProvider(
                    databaseURL: fixture.databaseURL
                ),
                uploadPolicy: MessageAttachmentUploadPolicy(isEnabled: true),
                attachmentRoot: attachmentRoot
            ),
            connector: mediaConnector
        )
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store,
            policy: policy,
            connector: textConnector,
            deliveryLedger: ledger,
            attachmentDeliveryCoordinator: attachmentDelivery,
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        XCTAssertThrowsError(try pipeline.run()) { error in
            XCTAssertEqual(
                error as? MessageAttachmentDeliveryError,
                .deliveryUnconfirmed
            )
        }
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 0))
        XCTAssertEqual(textConnector.deliveries.count, 1)
        XCTAssertEqual(mediaConnector.attemptCount, 1)

        let retry = try pipeline.run()

        XCTAssertEqual(retry.deliveredCount, 1)
        XCTAssertEqual(retry.deliveredAttachmentCount, 0)
        XCTAssertEqual(retry.duplicateAttachmentCount, 0)
        XCTAssertEqual(retry.unconfirmedAttachmentCount, 1)
        XCTAssertEqual(retry.confirmedAttachmentCount, 0)
        XCTAssertEqual(textConnector.deliveries.count, 1)
        XCTAssertEqual(mediaConnector.attemptCount, 1)
        XCTAssertTrue(mediaConnector.deliveredData.isEmpty)
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 1))
        XCTAssertTrue(ledger.records.keys.allSatisfy { $0.count == 64 })
        XCTAssertFalse(ledger.records.keys.contains { $0.contains("photo") })
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
            attributedBodyData: nil,
            senderIdentifier: sender,
            conversationIdentifiers: conversations,
            attachmentCount: 0,
            attachmentMIMETypes: []
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

    func deliver(_ envelope: MessageConnectorEnvelope) throws -> MessageDeliveryOutcome {
        let syntheticGUID = envelope.body == "two" ? "second" : "first"
        if syntheticGUID == failingGUID && !hasFailed {
            hasFailed = true
            throw TelegramBotConnectorError.apiFailure(
                code: 500,
                description: "definite rejection"
            )
        }
        guard deliveredKeys.insert(envelope.deliveryKey).inserted else { return .duplicate }
        deliveredGUIDs.append(syntheticGUID)
        return .delivered
    }
}

private final class AmbiguousFailOnceConnector: MessageForwardingConnector {
    private(set) var attemptCount = 0

    func deliver(_ envelope: MessageConnectorEnvelope) throws -> MessageDeliveryOutcome {
        attemptCount += 1
        throw TelegramBotConnectorError.transportFailure
    }
}

private final class FailOnceAttachmentConnector: MessageAttachmentForwardingConnector {
    private(set) var attemptCount = 0
    private(set) var deliveredData: [Data] = []

    func deliver(_ attachment: LoadedMessageAttachment) throws {
        attemptCount += 1
        if attemptCount == 1 { throw TestError.failed }
        deliveredData.append(attachment.data)
    }

    private enum TestError: Error {
        case failed
    }
}
