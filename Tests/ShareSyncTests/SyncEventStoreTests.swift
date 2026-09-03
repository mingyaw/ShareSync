import Foundation
import XCTest
@testable import ShareSync

final class SyncEventStoreTests: XCTestCase {
    func testResultPostEventSummarizesSyncResult() {
        let result = SyncResult(
            syncBatchId: "batch-001",
            targetDeviceId: "ios-device-001",
            results: [
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "photo-001",
                    targetItemId: "local-001",
                    status: .synced,
                    errorCode: nil
                ),
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "photo-002",
                    targetItemId: nil,
                    status: .skipped,
                    errorCode: nil
                ),
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "photo-003",
                    targetItemId: nil,
                    status: .failed,
                    errorCode: "SS-NET-002"
                ),
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "photo-004",
                    targetItemId: nil,
                    status: .conflicted,
                    errorCode: "SS-PHOTO-409"
                )
            ]
        )

        let event = SyncEvent.fromResultPost(
            result: result,
            status: .success,
            recordedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(event.phase, .resultPost)
        XCTAssertEqual(event.status, .success)
        XCTAssertEqual(event.syncBatchId, "batch-001")
        XCTAssertEqual(event.targetDeviceId, "ios-device-001")
        XCTAssertEqual(event.photoCount, 4)
        XCTAssertEqual(event.syncedCount, 1)
        XCTAssertEqual(event.skippedCount, 1)
        XCTAssertEqual(event.failedCount, 2)
        XCTAssertEqual(event.successfulCount, 2)
    }

    func testFileStorePersistsEventsInOrder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncEventStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("sync-events.json")
        let store = FileSyncEventStore(fileURL: fileURL)

        try store.append(syncEvent(syncBatchId: "batch-001", recordedAt: Date(timeIntervalSince1970: 1)))
        try store.append(syncEvent(syncBatchId: "batch-002", recordedAt: Date(timeIntervalSince1970: 2)))

        let reloaded = FileSyncEventStore(fileURL: fileURL)
        let events = try reloaded.all()

        XCTAssertEqual(events.map(\.syncBatchId), ["batch-001", "batch-002"])
        XCTAssertEqual(try reloaded.latest()?.syncBatchId, "batch-002")
        XCTAssertEqual(try reloaded.latestSuccessfulSync()?.syncBatchId, "batch-002")
    }

    func testFileStoreKeepsMostRecentEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncEventStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileSyncEventStore(fileURL: directory.appendingPathComponent("sync-events.json"))

        for index in 0..<55 {
            try store.append(
                syncEvent(
                    syncBatchId: "batch-\(String(format: "%03d", index))",
                    recordedAt: Date(timeIntervalSince1970: TimeInterval(index))
                )
            )
        }

        let events = try store.all()

        XCTAssertEqual(events.count, 50)
        XCTAssertEqual(events.first?.syncBatchId, "batch-005")
        XCTAssertEqual(events.last?.syncBatchId, "batch-054")
    }

    func testClearRemovesPersistedEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncEventStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("sync-events.json")
        let store = FileSyncEventStore(fileURL: fileURL)

        try store.append(syncEvent(syncBatchId: "batch-001", recordedAt: Date()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try store.clear()

        XCTAssertEqual(try store.all(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private func syncEvent(syncBatchId: String, recordedAt: Date) -> SyncEvent {
        SyncEvent(
            id: UUID(),
            phase: .importPhotos,
            status: .success,
            recordedAt: recordedAt,
            sourceDeviceId: "android-device-001",
            targetDeviceId: "ios-device-001",
            syncBatchId: syncBatchId,
            photoCount: 1,
            syncedCount: 1,
            skippedCount: 0,
            failedCount: 0,
            errorCode: nil
        )
    }
}
