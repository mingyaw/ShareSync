import XCTest
@testable import ShareSyncMessageBridge

final class ControlledMessageValidationSessionTests: XCTestCase {
    func testActivationEstablishesBaselineWithoutReadingHistory() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        try fixture.insertMessage(guid: "existing", body: "must not be reported")
        let store = try makeStore()
        let session = ControlledMessageValidationSession(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store
        )

        XCTAssertEqual(try session.activate(), .baselineEstablished(MessageCursor(rowID: 1)))
        var consumed = false
        let summary = try session.poll { _ in consumed = true }

        XCTAssertTrue(summary.isEmpty)
        XCTAssertFalse(consumed)
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 1))
    }

    func testExistingBaselineIsNotReplacedOnRestart() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        let store = try makeStore()
        try store.store.save(MessageCursor(rowID: 42))
        let session = ControlledMessageValidationSession(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store
        )

        XCTAssertEqual(try session.activate(), .alreadyActive(MessageCursor(rowID: 42)))
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 42))
    }

    func testPollRequiresExplicitActivation() throws {
        let fixture = try MessageBridgeFixture()
        let store = try makeStore()
        let session = ControlledMessageValidationSession(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store
        )

        XCTAssertThrowsError(try session.poll { _ in }) { error in
            XCTAssertEqual(error as? MessageValidationSessionError, .baselineRequired)
        }
    }

    func testPollExposesOnlyAggregateFidelitySummary() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        let store = try makeStore()
        let session = ControlledMessageValidationSession(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store
        )
        _ = try session.activate()
        try fixture.insertMessage(guid: "incoming", body: "private body", hasAttachments: true)
        try fixture.insertMessage(
            guid: "outgoing-reaction",
            body: nil,
            attributedBody: Data([0x01]),
            isFromMe: true,
            associatedType: 2000,
            associatedGUID: "incoming"
        )

        var delivered: MessageValidationSummary?
        let summary = try session.poll { delivered = $0 }

        XCTAssertEqual(summary.eventCount, 2)
        XCTAssertEqual(summary.incomingCount, 1)
        XCTAssertEqual(summary.outgoingCount, 1)
        XCTAssertEqual(summary.plainTextCount, 1)
        XCTAssertEqual(summary.richBodyCount, 1)
        XCTAssertEqual(summary.attachmentCount, 1)
        XCTAssertEqual(summary.associatedEventCount, 1)
        XCTAssertEqual(summary.missingSenderCount, 0)
        XCTAssertEqual(summary.services, ["iMessage"])
        XCTAssertEqual(delivered, summary)
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 2))
    }

    func testConsumerFailureDoesNotAdvanceCursor() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        let store = try makeStore()
        let session = ControlledMessageValidationSession(
            reader: MessageEventReader(databaseURL: fixture.databaseURL),
            cursorStore: store.store
        )
        _ = try session.activate()
        try fixture.insertMessage(guid: "retry-me", body: "private body")

        XCTAssertThrowsError(try session.poll { _ in throw ConsumerError.failed })
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 0))

        let retried = try session.poll { _ in }
        XCTAssertEqual(retried.eventCount, 1)
        XCTAssertEqual(try store.store.load(), MessageCursor(rowID: 1))
    }

    private func makeStore() throws -> (store: FileMessageCursorStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return (FileMessageCursorStore(fileURL: directory.appendingPathComponent("cursor.json")), directory)
    }

    private enum ConsumerError: Error {
        case failed
    }
}
