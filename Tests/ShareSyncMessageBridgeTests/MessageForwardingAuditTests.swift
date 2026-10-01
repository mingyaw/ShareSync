import XCTest
@testable import ShareSyncMessageBridge

final class MessageForwardingAuditTests: XCTestCase {
    func testAuditStoreIsBoundedNewestFirstAndContainsNoMessageIdentity() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("audit.json")
        let store = FileMessageForwardingAuditStore(fileURL: fileURL, maximumRecords: 2)

        for index in 1...3 {
            try store.append(MessageForwardingAuditRecord(
                id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(index)")!,
                timestamp: Date(timeIntervalSince1970: Double(index)),
                outcome: .completed,
                inspectedCount: index
            ))
        }

        XCTAssertEqual(try store.recent(limit: 10).map(\.inspectedCount), [3, 2])
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(raw.contains("sender"))
        XCTAssertFalse(raw.contains("body"))
        XCTAssertFalse(raw.contains("conversation"))
    }

    func testAuditedRunnerRecordsAggregateDenialReasons() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle(identifier: "not-allowed")
        try fixture.insertMessage(guid: "private-guid", body: "private-body")
        let cursorStore = try makeCursorStore()
        try cursorStore.store.save(MessageCursor(rowID: 0))
        let auditStore = MemoryAuditStore()
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: cursorStore.store,
            policy: MessageForwardingPolicy(allowedSenderIdentifiers: ["allowed"]),
            connector: InMemoryMessageForwardingConnector()
        )
        let runner = AuditedMessageForwardingRunner(
            pipeline: pipeline,
            auditStore: auditStore,
            now: { Date(timeIntervalSince1970: 10) }
        )

        _ = try runner.run()

        let record = try XCTUnwrap(auditStore.records.first)
        XCTAssertEqual(record.inspectedCount, 1)
        XCTAssertEqual(record.deniedCounts, ["senderNotAllowed": 1])
        XCTAssertEqual(record.deliveredCount, 0)
    }

    func testAuditExposesOnlyAggregateLoopPreventionCount() {
        let record = MessageForwardingAuditRecord(
            timestamp: Date(timeIntervalSince1970: 10),
            outcome: .completed,
            deniedCounts: [
                MessageForwardingDenialReason.outgoingMessage.rawValue: 2,
                MessageForwardingDenialReason.senderNotAllowed.rawValue: 3,
            ]
        )

        XCTAssertEqual(record.preventedLoopCount, 2)
    }

    func testAuditedRunnerRecordsPauseWithoutConsumingCursor() throws {
        let fixture = try MessageBridgeFixture()
        let cursorStore = try makeCursorStore()
        try cursorStore.store.save(MessageCursor(rowID: 4))
        let auditStore = MemoryAuditStore()
        let pipeline = MessageForwardingPipeline(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: cursorStore.store,
            policy: MessageForwardingPolicy(allowedSenderIdentifiers: []),
            connector: InMemoryMessageForwardingConnector(),
            runtimeGate: MessageForwardingRuntimeGate(isPaused: true)
        )
        let runner = AuditedMessageForwardingRunner(pipeline: pipeline, auditStore: auditStore)

        XCTAssertThrowsError(try runner.run())
        XCTAssertEqual(auditStore.records.first?.outcome, .paused)
        XCTAssertEqual(try cursorStore.store.load(), MessageCursor(rowID: 4))
    }

    private func makeCursorStore() throws -> (store: FileMessageCursorStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return (FileMessageCursorStore(fileURL: directory.appendingPathComponent("cursor.json")), directory)
    }
}

private final class MemoryAuditStore: MessageForwardingAuditStore {
    private(set) var records: [MessageForwardingAuditRecord] = []

    func append(_ record: MessageForwardingAuditRecord) throws {
        records.append(record)
    }

    func recent(limit: Int) throws -> [MessageForwardingAuditRecord] {
        Array(records.suffix(limit).reversed())
    }

    func clear() throws {
        records.removeAll()
    }
}
