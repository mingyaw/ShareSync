import Foundation
import XCTest
@testable import ShareSync

final class M0PhotoTransferPlannerTests: XCTestCase {
    func testNextTransferCandidatesIncludePhotosOnly() {
        let manifest = makeManifest(
            media: [
                makeAsset(assetId: "photo-001", mediaType: .photo),
                makeAsset(assetId: "video-001", mediaType: .video),
                makeAsset(assetId: "photo-002", mediaType: .photo),
            ]
        )
        let store = InMemoryMediaDownloadStateStore()

        let candidates = M0PhotoTransferPlanner().nextTransferCandidates(
            in: manifest,
            stateStore: store,
            limit: 10
        )

        XCTAssertEqual(candidates.map(\.assetId), ["photo-001", "photo-002"])
    }

    func testNextTransferCandidatesSkipCompletedPhotosAndKeepRetryablePhotos() {
        let importedPhoto = makeAsset(assetId: "photo-imported", mediaType: .photo)
        let skippedPhoto = makeAsset(assetId: "photo-skipped", mediaType: .photo)
        let failedPhoto = makeAsset(assetId: "photo-failed", mediaType: .photo)
        let missingPhoto = makeAsset(assetId: "photo-missing", mediaType: .photo)
        let queuedPhoto = makeAsset(assetId: "photo-queued", mediaType: .photo)
        let manifest = makeManifest(
            media: [
                importedPhoto,
                skippedPhoto,
                failedPhoto,
                missingPhoto,
                queuedPhoto,
                makeAsset(assetId: "video-001", mediaType: .video),
            ]
        )
        let store = InMemoryMediaDownloadStateStore()
        store.upsertQueued(asset: importedPhoto, now: Date(timeIntervalSince1970: 1))
        store.markImported(
            sourceAssetId: importedPhoto.assetId,
            photoLocalIdentifier: "photo-local-imported",
            now: Date(timeIntervalSince1970: 2)
        )
        store.upsertQueued(asset: skippedPhoto, now: Date(timeIntervalSince1970: 3))
        store.markSkipped(sourceAssetId: skippedPhoto.assetId, now: Date(timeIntervalSince1970: 4))
        store.upsertQueued(asset: failedPhoto, now: Date(timeIntervalSince1970: 5))
        store.markFailed(sourceAssetId: failedPhoto.assetId, errorCode: "SS-NET-002", now: Date(timeIntervalSince1970: 6))
        store.upsertQueued(asset: missingPhoto, now: Date(timeIntervalSince1970: 7))
        store.markMissing(sourceAssetId: missingPhoto.assetId, now: Date(timeIntervalSince1970: 8))
        store.upsertQueued(asset: queuedPhoto, now: Date(timeIntervalSince1970: 9))

        let candidates = M0PhotoTransferPlanner().nextTransferCandidates(
            in: manifest,
            stateStore: store,
            limit: 10
        )

        XCTAssertEqual(candidates.map(\.assetId), ["photo-failed", "photo-missing", "photo-queued"])
    }

    func testNextTransferCandidatesHonorsLimit() {
        let manifest = makeManifest(
            media: [
                makeAsset(assetId: "photo-001", mediaType: .photo),
                makeAsset(assetId: "photo-002", mediaType: .photo),
                makeAsset(assetId: "photo-003", mediaType: .photo),
            ]
        )

        let candidates = M0PhotoTransferPlanner().nextTransferCandidates(
            in: manifest,
            stateStore: InMemoryMediaDownloadStateStore(),
            limit: 2
        )

        XCTAssertEqual(candidates.map(\.assetId), ["photo-001", "photo-002"])
    }

    func testNextTransferCandidatesPrioritizeDownloadedPhotosBeforeNewDownloads() {
        let newPhoto = makeAsset(assetId: "photo-new", mediaType: .photo)
        let downloadedPhoto = makeAsset(assetId: "photo-downloaded", mediaType: .photo)
        let failedPhoto = makeAsset(assetId: "photo-failed", mediaType: .photo)
        let secondDownloadedPhoto = makeAsset(assetId: "photo-downloaded-2", mediaType: .photo)
        let manifest = makeManifest(
            media: [
                newPhoto,
                downloadedPhoto,
                failedPhoto,
                secondDownloadedPhoto,
            ]
        )
        let store = InMemoryMediaDownloadStateStore()
        store.upsertQueued(asset: downloadedPhoto, now: Date(timeIntervalSince1970: 1))
        store.markDownloaded(
            sourceAssetId: downloadedPhoto.assetId,
            localFileURL: URL(fileURLWithPath: "/tmp/photo-downloaded.jpg"),
            downloadedBytes: downloadedPhoto.size,
            now: Date(timeIntervalSince1970: 2)
        )
        store.upsertQueued(asset: failedPhoto, now: Date(timeIntervalSince1970: 3))
        store.markFailed(sourceAssetId: failedPhoto.assetId, errorCode: "SS-NET-002", now: Date(timeIntervalSince1970: 4))
        store.upsertQueued(asset: secondDownloadedPhoto, now: Date(timeIntervalSince1970: 5))
        store.markDownloaded(
            sourceAssetId: secondDownloadedPhoto.assetId,
            localFileURL: URL(fileURLWithPath: "/tmp/photo-downloaded-2.jpg"),
            downloadedBytes: secondDownloadedPhoto.size,
            now: Date(timeIntervalSince1970: 6)
        )

        let candidates = M0PhotoTransferPlanner().nextTransferCandidates(
            in: manifest,
            stateStore: store,
            limit: 10
        )

        XCTAssertEqual(candidates.map(\.assetId), [
            "photo-downloaded",
            "photo-downloaded-2",
            "photo-failed",
            "photo-new",
        ])
    }

    func testSyncResultRecordsIncludePhotosOnlyInManifestOrder() {
        let firstPhoto = makeAsset(assetId: "photo-001", mediaType: .photo)
        let video = makeAsset(assetId: "video-001", mediaType: .video)
        let secondPhoto = makeAsset(assetId: "photo-002", mediaType: .photo)
        let manifest = makeManifest(
            media: [
                firstPhoto,
                video,
                secondPhoto,
            ]
        )
        let store = InMemoryMediaDownloadStateStore()
        store.upsertQueued(asset: secondPhoto, now: Date(timeIntervalSince1970: 1))
        store.markImported(
            sourceAssetId: secondPhoto.assetId,
            photoLocalIdentifier: "photo-local-002",
            now: Date(timeIntervalSince1970: 2)
        )
        store.upsertQueued(asset: video, now: Date(timeIntervalSince1970: 3))
        store.markImported(
            sourceAssetId: video.assetId,
            photoLocalIdentifier: "video-local-001",
            now: Date(timeIntervalSince1970: 4)
        )
        store.upsertQueued(asset: firstPhoto, now: Date(timeIntervalSince1970: 5))
        store.markImported(
            sourceAssetId: firstPhoto.assetId,
            photoLocalIdentifier: "photo-local-001",
            now: Date(timeIntervalSince1970: 6)
        )

        let records = M0PhotoTransferPlanner().syncResultRecords(
            in: manifest,
            stateStore: store
        )

        XCTAssertEqual(records.map(\.sourceAssetId), ["photo-001", "photo-002"])
    }

    func testNextTransferCandidatesTreatSameAssetIdFromDifferentDeviceAsNewPhoto() {
        let currentDevicePhoto = makeAsset(
            assetId: "shared-media-id",
            mediaType: .photo,
            sourceDeviceId: "android-device-current"
        )
        let previousDevicePhoto = makeAsset(
            assetId: "shared-media-id",
            mediaType: .photo,
            sourceDeviceId: "android-device-previous"
        )
        let manifest = makeManifest(
            media: [currentDevicePhoto],
            sourceDeviceId: "android-device-current"
        )
        let store = InMemoryMediaDownloadStateStore()
        store.upsertQueued(asset: previousDevicePhoto, now: Date(timeIntervalSince1970: 1))
        store.markImported(
            sourceAssetId: previousDevicePhoto.assetId,
            photoLocalIdentifier: "previous-photo-local-id",
            now: Date(timeIntervalSince1970: 2)
        )

        let candidates = M0PhotoTransferPlanner().nextTransferCandidates(
            in: manifest,
            stateStore: store,
            limit: 10
        )

        XCTAssertEqual(candidates.map(\.assetId), ["shared-media-id"])
    }

    func testSyncResultRecordsExcludeSameAssetIdFromDifferentDevice() {
        let currentDevicePhoto = makeAsset(
            assetId: "shared-media-id",
            mediaType: .photo,
            sourceDeviceId: "android-device-current"
        )
        let previousDevicePhoto = makeAsset(
            assetId: "shared-media-id",
            mediaType: .photo,
            sourceDeviceId: "android-device-previous"
        )
        let manifest = makeManifest(
            media: [currentDevicePhoto],
            sourceDeviceId: "android-device-current"
        )
        let store = InMemoryMediaDownloadStateStore()
        store.upsertQueued(asset: previousDevicePhoto, now: Date(timeIntervalSince1970: 1))
        store.markImported(
            sourceAssetId: previousDevicePhoto.assetId,
            photoLocalIdentifier: "previous-photo-local-id",
            now: Date(timeIntervalSince1970: 2)
        )

        let records = M0PhotoTransferPlanner().syncResultRecords(
            in: manifest,
            stateStore: store
        )

        XCTAssertEqual(records, [])
    }

    private func makeManifest(
        media: [MediaAsset],
        sourceDeviceId: String = "android-device-001"
    ) -> SyncManifest {
        SyncManifest(
            version: 1,
            sourceDeviceId: sourceDeviceId,
            generatedAt: Date(timeIntervalSince1970: 1),
            cursor: "cursor-001",
            media: media,
            contacts: [],
            files: []
        )
    }

    private func makeAsset(
        assetId: String,
        mediaType: MediaType,
        sourceDeviceId: String = "android-device-001"
    ) -> MediaAsset {
        MediaAsset(
            assetId: assetId,
            sourceDeviceId: sourceDeviceId,
            mediaType: mediaType,
            fileName: "\(assetId).\(mediaType == .photo ? "jpg" : "mp4")",
            mimeType: mediaType == .photo ? "image/jpeg" : "video/mp4",
            size: 1024,
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
