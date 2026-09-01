import Foundation
import XCTest
@testable import ShareSync

final class SyncResultBuilderTests: XCTestCase {
    func testBuildMediaResultMapsTerminalRecords() {
        let result = SyncResultBuilder().buildMediaResult(
            syncBatchId: "batch-001",
            targetDeviceId: "ios-device-001",
            records: [
                makeRecord(
                    sourceAssetId: "media-imported",
                    status: .imported,
                    photoLocalIdentifier: "photo-local-001"
                ),
                makeRecord(
                    sourceAssetId: "media-skipped",
                    status: .skipped,
                    photoLocalIdentifier: "photo-local-002"
                ),
                makeRecord(
                    sourceAssetId: "media-failed",
                    status: .failed,
                    lastErrorCode: "SS-NET-002"
                ),
                makeRecord(
                    sourceAssetId: "media-missing",
                    status: .missing,
                    photoLocalIdentifier: "photo-local-003"
                )
            ]
        )

        XCTAssertEqual(result.syncBatchId, "batch-001")
        XCTAssertEqual(result.targetDeviceId, "ios-device-001")
        XCTAssertEqual(
            result.results,
            [
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-imported",
                    targetItemId: "photo-local-001",
                    status: .synced,
                    errorCode: nil
                ),
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-skipped",
                    targetItemId: "photo-local-002",
                    status: .skipped,
                    errorCode: nil
                ),
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-failed",
                    targetItemId: nil,
                    status: .failed,
                    errorCode: "SS-NET-002"
                ),
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-missing",
                    targetItemId: "photo-local-003",
                    status: .failed,
                    errorCode: "SS-MEDIA-002"
                )
            ]
        )
    }

    func testBuildMediaResultOmitsNonTerminalRecords() {
        let result = SyncResultBuilder().buildMediaResult(
            syncBatchId: "batch-001",
            targetDeviceId: "ios-device-001",
            records: [
                makeRecord(sourceAssetId: "media-queued", status: .queued),
                makeRecord(sourceAssetId: "media-downloading", status: .downloading),
                makeRecord(sourceAssetId: "media-downloaded", status: .downloaded)
            ]
        )

        XCTAssertEqual(result.results, [])
    }

    func testBuildMediaResultUsesFallbackErrorCodeForUnknownFailures() {
        let result = SyncResultBuilder().buildMediaResult(
            syncBatchId: "batch-001",
            targetDeviceId: "ios-device-001",
            records: [
                makeRecord(sourceAssetId: "media-nil-error", status: .failed),
                makeRecord(sourceAssetId: "media-empty-error", status: .failed, lastErrorCode: "  \n")
            ]
        )

        XCTAssertEqual(
            result.results,
            [
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-nil-error",
                    targetItemId: nil,
                    status: .failed,
                    errorCode: "SS-MEDIA-999"
                ),
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-empty-error",
                    targetItemId: nil,
                    status: .failed,
                    errorCode: "SS-MEDIA-999"
                )
            ]
        )
    }

    private func makeRecord(
        sourceAssetId: String,
        status: MediaDownloadStatus,
        photoLocalIdentifier: String? = nil,
        lastErrorCode: String? = nil
    ) -> MediaDownloadRecord {
        MediaDownloadRecord(
            sourceDeviceId: "android-device-001",
            sourceAssetId: sourceAssetId,
            sourceHash: nil,
            status: status,
            localFileURL: nil,
            photoLocalIdentifier: photoLocalIdentifier,
            downloadedBytes: 0,
            totalBytes: 2048,
            attemptCount: status == .failed ? 1 : 0,
            lastErrorCode: lastErrorCode,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    }
}
