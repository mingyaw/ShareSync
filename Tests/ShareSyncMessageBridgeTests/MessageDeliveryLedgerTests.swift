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
}
