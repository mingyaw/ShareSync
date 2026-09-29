import XCTest
@testable import ShareSyncMessageBridge

final class MessageCursorStoreTests: XCTestCase {
    func testSaveLoadAndClearCursor() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileMessageCursorStore(fileURL: directory.appendingPathComponent("cursor.json"))

        XCTAssertNil(try store.load())
        try store.save(MessageCursor(rowID: 42))
        XCTAssertEqual(try store.load(), MessageCursor(rowID: 42))
        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testUnknownEnvelopeVersionFailsClosed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("cursor.json")
        try Data(#"{"version":99,"cursor":{"rowID":1}}"#.utf8).write(to: fileURL)
        let store = FileMessageCursorStore(fileURL: fileURL)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? MessageCursorStoreError, .unsupportedVersion(99))
        }
    }
}
