import XCTest
@testable import ShareSyncMessageBridge

final class MessageEventReaderTests: XCTestCase {
    func testBaselineExcludesExistingHistoryAndReadsOnlyNewMessages() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        try fixture.insertMessage(guid: "existing", body: "history")
        let reader = MessageEventReader(databaseURL: fixture.databaseURL)

        let baseline = try reader.baselineCursor()
        try fixture.insertMessage(guid: "new-message", body: "controlled test", date: 2)
        let batch = try reader.events(after: baseline)

        XCTAssertEqual(batch.events.map(\.guid), ["new-message"])
        XCTAssertEqual(batch.events.first?.body, "controlled test")
        XCTAssertEqual(batch.events.first?.senderIdentifier, "synthetic-sender")
        XCTAssertEqual(batch.nextCursor.rowID, batch.events.first?.rowID)
    }

    func testAdvancingCursorDoesNotEmitSameMessageTwice() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        let reader = MessageEventReader(databaseURL: fixture.databaseURL)
        let baseline = try reader.baselineCursor()
        try fixture.insertMessage(guid: "only-once", body: "controlled test")

        let first = try reader.events(after: baseline)
        let second = try reader.events(after: first.nextCursor)

        XCTAssertEqual(first.events.map(\.guid), ["only-once"])
        XCTAssertTrue(second.events.isEmpty)
    }

    func testRichBodyWithoutPlainTextIsReportedForFutureDecoder() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        let reader = MessageEventReader(databaseURL: fixture.databaseURL)
        let baseline = try reader.baselineCursor()
        try fixture.insertMessage(
            guid: "rich-body",
            body: nil,
            attributedBody: Data([0x01, 0x02, 0x03])
        )

        let event = try XCTUnwrap(reader.events(after: baseline).events.first)

        XCTAssertNil(event.body)
        XCTAssertTrue(event.needsRichBodyDecoding)
    }

    func testBatchLimitIsBoundedAndCursorAdvances() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        let reader = MessageEventReader(databaseURL: fixture.databaseURL)
        let baseline = try reader.baselineCursor()
        for index in 0..<3 {
            try fixture.insertMessage(guid: "message-\(index)", body: "test")
        }

        let first = try reader.events(after: baseline, limit: 2)
        let second = try reader.events(after: first.nextCursor, limit: 2)

        XCTAssertEqual(first.events.count, 2)
        XCTAssertEqual(second.events.map(\.guid), ["message-2"])
    }

    func testConversationContextIsReadWhenSchemaSupportsIt() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        try fixture.insertChat(guid: "iMessage;-;group-id")
        try fixture.insertMessage(guid: "group-message", body: "controlled test")
        try fixture.linkMessage(rowID: 1)
        let reader = MessageEventReader(databaseURL: fixture.databaseURL)

        let event = try XCTUnwrap(reader.events(after: MessageCursor(rowID: 0)).events.first)

        XCTAssertEqual(event.conversationIdentifiers, ["iMessage;-;group-id"])
    }

    func testAttachmentMetadataExcludesFilePathsAndNames() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        try fixture.insertMessage(guid: "attachment-message", body: nil, hasAttachments: true)
        try fixture.insertAttachment(rowID: 1, mimeType: "image/jpeg")
        try fixture.insertAttachment(rowID: 2, mimeType: "application/pdf")
        try fixture.linkAttachment(rowID: 1, toMessage: 1)
        try fixture.linkAttachment(rowID: 2, toMessage: 1)
        let reader = MessageEventReader(databaseURL: fixture.databaseURL)

        let event = try XCTUnwrap(reader.events(after: MessageCursor(rowID: 0)).events.first)

        XCTAssertEqual(event.attachmentCount, 2)
        XCTAssertEqual(event.attachmentMIMETypes, ["image/jpeg", "application/pdf"])
    }

    func testUnsupportedSchemaFailsClosed() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.execute("ALTER TABLE message RENAME TO legacy_message")
        let reader = MessageEventReader(databaseURL: fixture.databaseURL)

        XCTAssertThrowsError(try reader.baselineCursor()) { error in
            guard case .unsupportedSchema(let missing) = error as? MessageBridgeError else {
                return XCTFail("Expected unsupported schema")
            }
            XCTAssertTrue(missing.contains("table:message"))
        }
    }
}
