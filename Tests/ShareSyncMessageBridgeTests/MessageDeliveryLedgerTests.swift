import XCTest
@testable import ShareSyncMessageBridge

final class MessageDeliveryLedgerTests: XCTestCase {
    func testFileLedgerPersistsOnlyOpaqueDeliveryState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("delivery-ledger.json")
        let first = FileMessageDeliveryLedgerStore(fileURL: fileURL)
        let date = Date(timeIntervalSince1970: 100)

        try first.markPending(deliveryKey: "opaque-key", at: date)
        XCTAssertEqual(try first.record(for: "opaque-key")?.state, .pending)

        let restarted = FileMessageDeliveryLedgerStore(fileURL: fileURL)
        try restarted.markDelivered(deliveryKey: "opaque-key", at: date)
        XCTAssertEqual(try restarted.record(for: "opaque-key")?.state, .delivered)
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(raw.contains("message body"))
    }

    func testPruneRetainsPendingAndRecentDeliveredRecords() throws {
        let ledger = InMemoryMessageDeliveryLedgerStore()
        try ledger.markDelivered(deliveryKey: "old", at: Date(timeIntervalSince1970: 10))
        try ledger.markDelivered(deliveryKey: "recent", at: Date(timeIntervalSince1970: 30))
        try ledger.markPending(deliveryKey: "pending", at: Date(timeIntervalSince1970: 10))

        try ledger.pruneDelivered(before: Date(timeIntervalSince1970: 20))

        XCTAssertNil(try ledger.record(for: "old"))
        XCTAssertNotNil(try ledger.record(for: "recent"))
        XCTAssertNotNil(try ledger.record(for: "pending"))
    }

    func testRateLimiterReturnsRetryDelay() {
        let limiter = MessageDeliveryRateLimiter(maximumDeliveries: 2, interval: 60)
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(limiter.reserve(at: start), .allowed)
        XCTAssertEqual(limiter.reserve(at: start.addingTimeInterval(1)), .allowed)
        XCTAssertEqual(limiter.reserve(at: start.addingTimeInterval(10)), .limited(retryAfter: 50))
        XCTAssertEqual(limiter.reserve(at: start.addingTimeInterval(60)), .allowed)
    }

    func testClearRemovesPersistedDeliveryState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileMessageDeliveryLedgerStore(
            fileURL: directory.appendingPathComponent("ledger.json")
        )
        try store.markDelivered(deliveryKey: "key", at: Date())

        try store.clear()

        XCTAssertNil(try store.record(for: "key"))
    }

    func testRemoveClearsOnlyRequestedDeliveryState() throws {
        let store = InMemoryMessageDeliveryLedgerStore()
        try store.markPending(deliveryKey: "retryable", at: Date())
        try store.markDelivered(deliveryKey: "confirmed", at: Date())

        try store.remove(deliveryKey: "retryable")

        XCTAssertNil(try store.record(for: "retryable"))
        XCTAssertEqual(try store.record(for: "confirmed")?.state, .delivered)
    }

    func testFileRemovePersistsAcrossStoreRestart() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("ledger.json")
        let store = FileMessageDeliveryLedgerStore(fileURL: fileURL)
        try store.markPending(deliveryKey: "retryable", at: Date())

        try store.remove(deliveryKey: "retryable")

        XCTAssertNil(try FileMessageDeliveryLedgerStore(fileURL: fileURL).record(for: "retryable"))
    }

    func testSeparateFileLedgerInstancesDoNotLoseConcurrentUpdates() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("ledger.json")
        let stores = (0..<4).map { _ in FileMessageDeliveryLedgerStore(fileURL: fileURL) }
        let errorLock = NSLock()
        var errors: [Error] = []

        DispatchQueue.concurrentPerform(iterations: 100) { index in
            do {
                try stores[index % stores.count].markDelivered(
                    deliveryKey: "key-\(index)",
                    at: Date(timeIntervalSince1970: Double(index))
                )
            } catch {
                errorLock.lock()
                errors.append(error)
                errorLock.unlock()
            }
        }

        XCTAssertTrue(errors.isEmpty)
        let reader = FileMessageDeliveryLedgerStore(fileURL: fileURL)
        for index in 0..<100 {
            XCTAssertEqual(try reader.record(for: "key-\(index)")?.state, .delivered)
        }
    }

    func testMalformedFileLedgerReportsPersistentStateFailure() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("ledger.json")
        try Data("not-json".utf8).write(to: fileURL)
        let store = FileMessageDeliveryLedgerStore(fileURL: fileURL)

        XCTAssertThrowsError(try store.record(for: "key")) { error in
            XCTAssertEqual(error as? MessageBridgePersistentStateError, .invalidData)
            XCTAssertTrue(error is MessageBridgePersistentStateFailure)
        }
    }
}
