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
        XCTAssertEqual(store.allRecords().map(\.sourceAssetId), ["media-001"])
        XCTAssertEqual(store.pendingRecords().map(\.sourceAssetId), ["media-001"])

        store.markDownloading(sourceAssetId: "media-001", downloadedBytes: 512, now: now.addingTimeInterval(1))
        XCTAssertEqual(store.record(for: "media-001")?.status, .downloading)
        XCTAssertEqual(store.record(for: "media-001")?.downloadedBytes, 512)

        let fileURL = URL(fileURLWithPath: "/tmp/media-001.jpg")
        store.markDownloaded(sourceAssetId: "media-001", localFileURL: fileURL, downloadedBytes: 2048, now: now.addingTimeInterval(2))
        XCTAssertEqual(store.record(for: "media-001")?.status, .downloaded)
        XCTAssertEqual(store.record(for: "media-001")?.localFileURL, fileURL)
        XCTAssertEqual(store.pendingRecords(), [])

        store.markImported(
            sourceAssetId: "media-001",
            photoLocalIdentifier: "photo-local-001",
            now: now.addingTimeInterval(3)
        )
        XCTAssertEqual(store.record(for: "media-001")?.status, .imported)
        XCTAssertNil(store.record(for: "media-001")?.localFileURL)
        XCTAssertEqual(store.record(for: "media-001")?.photoLocalIdentifier, "photo-local-001")
        XCTAssertEqual(
            store.importedMappings(),
            [
                MediaImportMapping(
                    sourceDeviceId: "android-demo-device",
                    sourceAssetId: "media-001",
                    sourceHash: nil,
                    photoLocalIdentifier: "photo-local-001",
                    importedAt: now.addingTimeInterval(3)
                )
            ]
        )
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

    func testFailedRecordKeepsPartialDownloadWhenRequeued() {
        let store = InMemoryMediaDownloadStateStore()
        let asset = makeAsset(assetId: "media-001", size: 2048)
        let fileURL = URL(fileURLWithPath: "/tmp/media-001.partial")

        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 1))
        store.markDownloaded(
            sourceAssetId: "media-001",
            localFileURL: fileURL,
            downloadedBytes: 512,
            now: Date(timeIntervalSince1970: 2)
        )
        store.markFailed(sourceAssetId: "media-001", errorCode: "SS-NET-002", now: Date(timeIntervalSince1970: 3))

        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 4))

        XCTAssertEqual(store.record(for: "media-001")?.status, .queued)
        XCTAssertEqual(store.record(for: "media-001")?.localFileURL, fileURL)
        XCTAssertEqual(store.record(for: "media-001")?.downloadedBytes, 512)
        XCTAssertNil(store.record(for: "media-001")?.lastErrorCode)
        XCTAssertEqual(store.resumablePartialRecords().map(\.sourceAssetId), ["media-001"])
    }

    func testResumablePartialRecordsExcludeFullDownloadsAndRecordsWithoutFiles() {
        let store = InMemoryMediaDownloadStateStore()
        let partialAsset = makeAsset(assetId: "media-partial", size: 2048)
        let fullAsset = makeAsset(assetId: "media-full", size: 2048)
        let noFileAsset = makeAsset(assetId: "media-no-file", size: 2048)

        store.upsertQueued(asset: partialAsset, now: Date(timeIntervalSince1970: 1))
        store.markDownloaded(
            sourceAssetId: "media-partial",
            localFileURL: URL(fileURLWithPath: "/tmp/media-partial.jpg"),
            downloadedBytes: 512,
            now: Date(timeIntervalSince1970: 2)
        )
        store.markFailed(sourceAssetId: "media-partial", errorCode: "SS-NET-002", now: Date(timeIntervalSince1970: 3))
        store.upsertQueued(asset: fullAsset, now: Date(timeIntervalSince1970: 4))
        store.markDownloaded(
            sourceAssetId: "media-full",
            localFileURL: URL(fileURLWithPath: "/tmp/media-full.jpg"),
            downloadedBytes: 2048,
            now: Date(timeIntervalSince1970: 5)
        )
        store.upsertQueued(asset: noFileAsset, now: Date(timeIntervalSince1970: 6))
        store.markDownloading(sourceAssetId: "media-no-file", downloadedBytes: 128, now: Date(timeIntervalSince1970: 7))

        XCTAssertEqual(store.resumablePartialRecords().map(\.sourceAssetId), ["media-partial"])
    }

    func testImportedRecordsAreNotRequeued() {
        let store = InMemoryMediaDownloadStateStore()
        let asset = makeAsset(assetId: "media-001", size: 2048)

        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 1))
        store.markImported(
            sourceAssetId: "media-001",
            photoLocalIdentifier: "photo-local-001",
            now: Date(timeIntervalSince1970: 2)
        )

        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(store.record(for: "media-001")?.status, .imported)
        XCTAssertEqual(store.importedMappings().map(\.sourceAssetId), ["media-001"])
    }

    func testImportedRecordClearsDownloadedFileURL() {
        let store = InMemoryMediaDownloadStateStore()
        let asset = makeAsset(assetId: "media-001", size: 2048)
        let fileURL = URL(fileURLWithPath: "/tmp/media-001.jpg")

        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 1))
        store.markDownloaded(
            sourceAssetId: "media-001",
            localFileURL: fileURL,
            downloadedBytes: 2048,
            now: Date(timeIntervalSince1970: 2)
        )
        store.markImported(
            sourceAssetId: "media-001",
            photoLocalIdentifier: "photo-local-001",
            now: Date(timeIntervalSince1970: 3)
        )

        XCTAssertEqual(store.record(for: "media-001")?.status, .imported)
        XCTAssertNil(store.record(for: "media-001")?.localFileURL)
        XCTAssertEqual(store.record(for: "media-001")?.downloadedBytes, 2048)
    }

    func testFileStorePersistsImportedMappings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncStateTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("media-download-state.json")
        let asset = makeAsset(assetId: "media-001", size: 2048)

        let store = FileMediaDownloadStateStore(fileURL: fileURL)
        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 1))
        store.markImported(
            sourceAssetId: "media-001",
            photoLocalIdentifier: "photo-local-001",
            now: Date(timeIntervalSince1970: 2)
        )

        let reloadedStore = FileMediaDownloadStateStore(fileURL: fileURL)
        XCTAssertEqual(
            reloadedStore.importedMappings(),
            [
                MediaImportMapping(
                    sourceDeviceId: "android-demo-device",
                    sourceAssetId: "media-001",
                    sourceHash: nil,
                    photoLocalIdentifier: "photo-local-001",
                    importedAt: Date(timeIntervalSince1970: 2)
                )
            ]
        )
    }

    func testFileStoreLoadsLatestRecordWhenPersistedStateContainsDuplicateAssetIds() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncStateTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("media-download-state.json")
        let olderRecord = makeRecord(
            sourceAssetId: "media-001",
            status: .failed,
            lastErrorCode: "SS-NET-002",
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let newerRecord = makeRecord(
            sourceAssetId: "media-001",
            status: .imported,
            photoLocalIdentifier: "photo-local-001",
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([olderRecord, newerRecord]).write(to: fileURL)

        let store = FileMediaDownloadStateStore(fileURL: fileURL)

        XCTAssertEqual(store.allRecords().map(\.sourceAssetId), ["media-001"])
        XCTAssertEqual(store.record(for: "media-001")?.status, .imported)
        XCTAssertEqual(store.record(for: "media-001")?.photoLocalIdentifier, "photo-local-001")
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

    func testInMemoryStoreClearRemovesAllRecords() {
        let store = InMemoryMediaDownloadStateStore()
        store.upsertQueued(asset: makeAsset(assetId: "media-001", size: 2048), now: Date(timeIntervalSince1970: 1))

        store.clear()

        XCTAssertNil(store.record(for: "media-001"))
        XCTAssertEqual(store.allRecords(), [])
        XCTAssertEqual(store.pendingRecords(), [])
        XCTAssertEqual(store.resumablePartialRecords(), [])
        XCTAssertEqual(store.importedMappings(), [])
    }

    func testFileStoreClearRemovesPersistedRecords() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncStateTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("media-download-state.json")
        let store = FileMediaDownloadStateStore(fileURL: fileURL)

        store.upsertQueued(asset: makeAsset(assetId: "media-001", size: 2048), now: Date(timeIntervalSince1970: 1))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        store.clear()

        XCTAssertEqual(store.allRecords(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(FileMediaDownloadStateStore(fileURL: fileURL).allRecords(), [])
    }

    func testFileStoreResumablePartialRecordsRequireExistingFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncStateTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("media-download-state.json")
        let partialURL = directory.appendingPathComponent("media-001.partial")
        let asset = makeAsset(assetId: "media-001", size: 2048)
        try Data("partial".utf8).write(to: partialURL)

        let store = FileMediaDownloadStateStore(fileURL: fileURL)
        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 1))
        store.markDownloaded(
            sourceAssetId: "media-001",
            localFileURL: partialURL,
            downloadedBytes: 7,
            now: Date(timeIntervalSince1970: 2)
        )
        store.markFailed(sourceAssetId: "media-001", errorCode: "SS-NET-002", now: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(store.resumablePartialRecords().map(\.sourceAssetId), ["media-001"])
    }

    func testFileStoreResumablePartialRecordsExcludeStaleFileReferences() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncStateTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("media-download-state.json")
        let stalePartialURL = directory.appendingPathComponent("missing-media-001.partial")
        let asset = makeAsset(assetId: "media-001", size: 2048)

        let store = FileMediaDownloadStateStore(fileURL: fileURL)
        store.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 1))
        store.markDownloaded(
            sourceAssetId: "media-001",
            localFileURL: stalePartialURL,
            downloadedBytes: 512,
            now: Date(timeIntervalSince1970: 2)
        )
        store.markFailed(sourceAssetId: "media-001", errorCode: "SS-NET-002", now: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(store.record(for: "media-001")?.downloadedBytes, 512)
        XCTAssertEqual(store.resumablePartialRecords(), [])
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

    private func makeRecord(
        sourceAssetId: String,
        status: MediaDownloadStatus,
        photoLocalIdentifier: String? = nil,
        lastErrorCode: String? = nil,
        updatedAt: Date
    ) -> MediaDownloadRecord {
        MediaDownloadRecord(
            sourceDeviceId: "android-demo-device",
            sourceAssetId: sourceAssetId,
            sourceHash: nil,
            status: status,
            localFileURL: nil,
            photoLocalIdentifier: photoLocalIdentifier,
            downloadedBytes: status == .imported ? 2048 : 0,
            totalBytes: 2048,
            attemptCount: status == .failed ? 1 : 0,
            lastErrorCode: lastErrorCode,
            updatedAt: updatedAt
        )
    }
}
