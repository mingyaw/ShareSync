import Foundation
import XCTest
@testable import ShareSync

final class SyncResultStoreTests: XCTestCase {
    func testFileStorePersistsLatestSyncResult() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncResultStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("latest-sync-result.json")
        let store = FileSyncResultStore(fileURL: fileURL)
        let result = SyncResult(
            syncBatchId: "batch-001",
            targetDeviceId: "ios-device-001",
            results: [
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-001",
                    targetItemId: "photo-local-001",
                    status: .synced,
                    errorCode: nil
                ),
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-002",
                    targetItemId: nil,
                    status: .failed,
                    errorCode: "SS-NET-002"
                )
            ]
        )

        XCTAssertNil(try store.latest())

        try store.save(result)

        XCTAssertEqual(try store.latest(), result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testFileStoreOverwritesLatestSyncResult() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncResultStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileSyncResultStore(fileURL: directory.appendingPathComponent("latest-sync-result.json"))
        let first = SyncResult(syncBatchId: "batch-001", targetDeviceId: "ios-device-001", results: [])
        let second = SyncResult(
            syncBatchId: "batch-002",
            targetDeviceId: "ios-device-001",
            results: [
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-001",
                    targetItemId: nil,
                    status: .skipped,
                    errorCode: nil
                )
            ]
        )

        try store.save(first)
        try store.save(second)

        XCTAssertEqual(try store.latest(), second)
    }
}
