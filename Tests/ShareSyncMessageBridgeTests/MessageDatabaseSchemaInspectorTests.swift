import XCTest
@testable import ShareSyncMessageBridge

final class MessageDatabaseSchemaInspectorTests: XCTestCase {
    func testSyntheticMessagesSchemaSupportsIncrementalTextEvents() throws {
        let fixture = try MessageBridgeFixture()

        let schema = try MessageDatabaseSchemaInspector().inspect(databaseURL: fixture.databaseURL)

        XCTAssertTrue(schema.supportsIncrementalTextEvents)
        XCTAssertTrue(schema.supportsConversationContext)
        XCTAssertEqual(schema.fingerprint.count, 64)
        XCTAssertTrue(schema.tables.contains("message"))
        XCTAssertTrue(schema.columnsByTable["message", default: []].contains("guid"))
    }

    func testFingerprintIsStableForSameSchema() throws {
        let fixture = try MessageBridgeFixture()
        let inspector = MessageDatabaseSchemaInspector()

        let first = try inspector.inspect(databaseURL: fixture.databaseURL)
        let second = try inspector.inspect(databaseURL: fixture.databaseURL)

        XCTAssertEqual(first.fingerprint, second.fingerprint)
    }

    func testMissingDatabaseIsRejectedWithoutCreatingAFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        XCTAssertThrowsError(try MessageDatabaseSchemaInspector().inspect(databaseURL: url)) { error in
            XCTAssertEqual(error as? MessageBridgeError, .databaseUnavailable)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
