import XCTest
@testable import ShareSyncMessageBridge

final class MessageDatabaseAccessProbeTests: XCTestCase {
    func testSupportedSyntheticDatabaseIsAvailable() throws {
        let fixture = try MessageBridgeFixture()

        let status = MessageDatabaseAccessProbe().status(databaseURL: fixture.databaseURL)

        guard case .available(let fingerprint) = status else {
            return XCTFail("Expected available status")
        }
        XCTAssertEqual(fingerprint.count, 64)
    }

    func testMissingDatabaseIsUnavailable() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        XCTAssertEqual(MessageDatabaseAccessProbe().status(databaseURL: url), .unavailable)
    }

    func testUnsupportedSchemaListsMissingRequirements() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.execute("ALTER TABLE message RENAME TO legacy_message")

        let status = MessageDatabaseAccessProbe().status(databaseURL: fixture.databaseURL)

        guard case .unsupportedSchema(_, let missing) = status else {
            return XCTFail("Expected unsupported schema")
        }
        XCTAssertTrue(missing.contains("table:message"))
    }
}
