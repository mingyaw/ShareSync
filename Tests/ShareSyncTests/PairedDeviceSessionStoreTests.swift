import Foundation
import XCTest
@testable import ShareSync

final class PairedDeviceSessionStoreTests: XCTestCase {
    func testFileStorePersistsPairedDeviceSession() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncPairedDeviceSessionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("paired-device-session.json")
        let store = FilePairedDeviceSessionStore(fileURL: fileURL)
        let session = makeSession()

        XCTAssertNil(try store.load())

        try store.save(session)

        XCTAssertEqual(try store.load(), session)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testFileStoreClearRemovesPairedDeviceSession() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncPairedDeviceSessionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("paired-device-session.json")
        let store = FilePairedDeviceSessionStore(fileURL: fileURL)

        try store.save(makeSession())
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try store.clear()

        XCTAssertNil(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private func makeSession() -> PairedDeviceSession {
        PairedDeviceSession(
            host: "192.168.1.20",
            port: 48291,
            device: TrustedDevice(
                deviceId: "android-demo-device",
                deviceName: "Pixel Demo",
                platform: "android",
                publicKey: "m0-public-key",
                pairingToken: "pairing-token-001",
                pairedAt: Date(timeIntervalSince1970: 1),
                lastSeenAt: nil,
                trustStatus: .trusted
            ),
            endpointUpdatedAt: Date(timeIntervalSince1970: 2)
        )
    }
}

extension PairedDeviceSessionStoreTests {
    func testClearingPairingDoesNotClearIOSSyncStateFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncPairedDeviceSessionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pairingStore = FilePairedDeviceSessionStore(fileURL: directory.appendingPathComponent("paired-device-session.json"))
        let downloadStore = FileMediaDownloadStateStore(fileURL: directory.appendingPathComponent("media-download-state.json"))
        let resultStore = FileSyncResultStore(fileURL: directory.appendingPathComponent("latest-sync-result.json"))
        let eventStore = FileSyncEventStore(fileURL: directory.appendingPathComponent("sync-events.json"))
        let asset = mediaAsset()

        try pairingStore.save(makeSession())
        downloadStore.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 3))
        downloadStore.markImported(
            sourceAssetId: asset.assetId,
            photoLocalIdentifier: "photo-local-001",
            now: Date(timeIntervalSince1970: 4)
        )
        try resultStore.save(syncResult())
        try eventStore.append(syncEvent())

        try pairingStore.clear()

        XCTAssertNil(try pairingStore.load())
        XCTAssertEqual(downloadStore.record(for: asset)?.status, .imported)
        XCTAssertEqual(try resultStore.latest()?.syncBatchId, "batch-001")
        XCTAssertEqual(try eventStore.latest()?.syncBatchId, "batch-001")
    }

    func testResettingIOSSyncStateDoesNotClearPairing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncPairedDeviceSessionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pairingStore = FilePairedDeviceSessionStore(fileURL: directory.appendingPathComponent("paired-device-session.json"))
        let downloadStore = FileMediaDownloadStateStore(fileURL: directory.appendingPathComponent("media-download-state.json"))
        let resultStore = FileSyncResultStore(fileURL: directory.appendingPathComponent("latest-sync-result.json"))
        let eventStore = FileSyncEventStore(fileURL: directory.appendingPathComponent("sync-events.json"))
        let asset = mediaAsset()
        let session = makeSession()

        try pairingStore.save(session)
        downloadStore.upsertQueued(asset: asset, now: Date(timeIntervalSince1970: 3))
        try resultStore.save(syncResult())
        try eventStore.append(syncEvent())

        downloadStore.clear()
        try resultStore.clear()
        try eventStore.clear()

        XCTAssertEqual(try pairingStore.load(), session)
        XCTAssertEqual(downloadStore.allRecords(), [])
        XCTAssertNil(try resultStore.latest())
        XCTAssertNil(try eventStore.latest())
    }

    func testPairedDeviceSessionDecodesLegacyHostAndPort() throws {
        let json = """
        {
          "host": "192.168.1.20",
          "port": 48291,
          "device": {
            "deviceId": "android-demo-device",
            "deviceName": "Pixel Demo",
            "platform": "android",
            "publicKey": "m0-public-key",
            "pairingToken": "pairing-token-001",
            "pairedAt": "1970-01-01T00:00:01Z",
            "lastSeenAt": null,
            "trustStatus": "trusted"
          }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let session = try JSONDecoder.pairedDeviceSessionTestDecoder.decode(PairedDeviceSession.self, from: data)

        XCTAssertEqual(session.host, "192.168.1.20")
        XCTAssertEqual(session.port, 48291)
        XCTAssertEqual(session.lastKnownEndpoint.updatedAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(session.device.deviceId, "android-demo-device")
    }

    private func mediaAsset() -> MediaAsset {
        MediaAsset(
            assetId: "media-001",
            sourceDeviceId: "android-demo-device",
            mediaType: .photo,
            fileName: "IMG_0001.jpg",
            mimeType: "image/jpeg",
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

    private func syncResult() -> SyncResult {
        SyncResult(
            syncBatchId: "batch-001",
            targetDeviceId: "ios-device-001",
            results: [
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-001",
                    targetItemId: "photo-local-001",
                    status: .synced,
                    errorCode: nil
                )
            ]
        )
    }

    private func syncEvent() -> SyncEvent {
        SyncEvent(
            id: UUID(),
            phase: .resultPost,
            status: .success,
            recordedAt: Date(timeIntervalSince1970: 5),
            sourceDeviceId: "android-demo-device",
            targetDeviceId: "ios-device-001",
            syncBatchId: "batch-001",
            photoCount: 1,
            syncedCount: 1,
            skippedCount: 0,
            failedCount: 0,
            errorCode: nil
        )
    }
}

private extension JSONDecoder {
    static var pairedDeviceSessionTestDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
