import Foundation
import XCTest
@testable import ShareSync

final class MediaDownloadStateTests: XCTestCase {
    func testQueueAndDownloadLifecycle() {
        let store = InMemoryMediaDownloadStateStore()
        let asset = makeAsset(assetId: "media-001", size: 2048)
        let now = Date(timeIntervalSince1970: 1)

        store.upsertQueued(asset: asset, now: now)
        XCTAssertEqual(store.record(for: "media-001")?.status, .queued)
        XCTAssertEqual(store.pendingRecords().map(\.sourceAssetId), ["media-001"])

        store.markDownloading(sourceAssetId: "media-001", downloadedBytes: 512, now: now.addingTimeInterval(1))
        XCTAssertEqual(store.record(for: "media-001")?.status, .downloading)
        XCTAssertEqual(store.record(for: "media-001")?.downloadedBytes, 512)

        let fileURL = URL(fileURLWithPath: "/tmp/media-001.jpg")
        store.markDownloaded(sourceAssetId: "media-001", localFileURL: fileURL, downloadedBytes: 2048, now: now.addingTimeInterval(2))
        XCTAssertEqual(store.record(for: "media-001")?.status, .downloaded)
        XCTAssertEqual(store.record(for: "media-001")?.localFileURL, fileURL)
        XCTAssertEqual(store.pendingRecords(), [])

        store.markImported(sourceAssetId: "media-001", now: now.addingTimeInterval(3))
        XCTAssertEqual(store.record(for: "media-001")?.status, .imported)
    }

    func testCompletedRecordsAreNotRequeued() {
        let store = InMemoryMediaDownloadStateStore()
        let asset = makeAsset(assetId: "media-001", size: 2048)

        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 1))
        store.markDownloaded(
            sourceAssetId: "media-001",
            localFileURL: URL(fileURLWithPath: "/tmp/media-001.jpg"),
            downloadedBytes: 2048,
            now: Date(timeIntervalSince1970: 2)
        )

        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(store.record(for: "media-001")?.status, .downloaded)
    }

    func testFailedRecordsRemainPendingWithAttemptCount() {
        let store = InMemoryMediaDownloadStateStore()
        let asset = makeAsset(assetId: "media-001", size: 2048)

        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 1))
        store.markFailed(sourceAssetId: "media-001", errorCode: "SS-NET-002", now: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(store.record(for: "media-001")?.status, .failed)
        XCTAssertEqual(store.record(for: "media-001")?.attemptCount, 1)
        XCTAssertEqual(store.record(for: "media-001")?.lastErrorCode, "SS-NET-002")
        XCTAssertEqual(store.pendingRecords().map(\.sourceAssetId), ["media-001"])
    }

    private func makeAsset(assetId: String, size: Int64) -> MediaAsset {
        MediaAsset(
            assetId: assetId,
            sourceDeviceId: "android-demo-device",
            mediaType: .photo,
            fileName: "\(assetId).jpg",
            mimeType: "image/jpeg",
            size: size,
            sha256: nil,
            createdAt: nil,
            modifiedAt: nil,
            takenAt: nil,
            width: nil,
            height: nil,
            durationMs: nil,
            relativePath: "DCIM/Camera"
        )
    }
}

