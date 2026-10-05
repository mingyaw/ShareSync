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

    func testSeparateCursorInstancesSerializeConcurrentReadsAndWrites() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("cursor.json")
        let stores = (0..<4).map { _ in FileMessageCursorStore(fileURL: fileURL) }
        let errorLock = NSLock()
        var errors: [Error] = []

        DispatchQueue.concurrentPerform(iterations: 100) { index in
            do {
                let store = stores[index % stores.count]
                try store.save(MessageCursor(rowID: Int64(index)))
                _ = try store.load()
            } catch {
                errorLock.lock()
                errors.append(error)
                errorLock.unlock()
            }
        }

        XCTAssertTrue(errors.isEmpty)
        XCTAssertNotNil(try FileMessageCursorStore(fileURL: fileURL).load())
    }

    func testMalformedCursorReportsPersistentStateFailure() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("cursor.json")
        try Data("{".utf8).write(to: fileURL)

        XCTAssertThrowsError(try FileMessageCursorStore(fileURL: fileURL).load()) { error in
            XCTAssertEqual(error as? MessageBridgePersistentStateError, .invalidData)
            XCTAssertTrue(error is MessageBridgePersistentStateFailure)
        }
    }
}
