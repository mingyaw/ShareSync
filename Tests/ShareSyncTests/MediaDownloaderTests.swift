import CryptoKit
import Foundation
import XCTest
@testable import ShareSync

final class MediaDownloaderTests: XCTestCase {
    func testDownloadMediaWritesFileAndMarksDownloaded() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let data = Data("demo-photo".utf8)
        let asset = makeAsset(
            assetId: "mediastore-1-42",
            fileName: "IMG_0042.jpg",
            size: Int64(data.count),
            sha256: sha256(data)
        )
        let store = InMemoryMediaDownloadStateStore()
        let session = StubMediaDataSession(
            data: data,
            response: HTTPURLResponse(
                url: URL(string: "http://192.168.1.10:48291/v1/media/mediastore-1-42")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
        let downloader = MediaDownloader(
            session: session,
            downloadDirectory: directory,
            now: { Date(timeIntervalSince1970: 10) }
        )

        let results = await downloader.downloadMedia(
            assets: [asset],
            host: "192.168.1.10",
            port: 48291,
            stateStore: store
        )

        XCTAssertEqual(results.map(\.assetId), ["mediastore-1-42"])
        let record = try XCTUnwrap(store.record(for: "mediastore-1-42"))
        XCTAssertEqual(record.status, .downloaded)
        XCTAssertEqual(record.downloadedBytes, Int64(data.count))
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(record.localFileURL)), data)
        XCTAssertEqual(session.requests.map { $0.url?.path }, ["/v1/media/mediastore-1-42"])
    }

    func testDownloadMediaSendsPairingTokenHeader() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let data = Data("demo-photo".utf8)
        let asset = makeAsset(
            assetId: "mediastore-1-48",
            fileName: "IMG_0048.jpg",
            size: Int64(data.count),
            sha256: sha256(data)
        )
        let store = InMemoryMediaDownloadStateStore()
        let session = StubMediaDataSession(
            data: data,
            response: HTTPURLResponse(
                url: URL(string: "http://192.168.1.10:48291/v1/media/mediastore-1-48")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
        let downloader = MediaDownloader(session: session, downloadDirectory: directory)

        _ = await downloader.downloadMedia(
            assets: [asset],
            host: "192.168.1.10",
            port: 48291,
            stateStore: store,
            pairingToken: "pairing-token-001"
        )

        XCTAssertEqual(
            session.requests.first?.value(forHTTPHeaderField: "X-ShareSync-Pairing-Token"),
            "pairing-token-001"
        )
    }

    func testChecksumMismatchMarksFailed() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let asset = makeAsset(
            assetId: "mediastore-1-43",
            fileName: "IMG_0043.jpg",
            size: 10,
            sha256: String(repeating: "0", count: 64)
        )
        let store = InMemoryMediaDownloadStateStore()
        let session = StubMediaDataSession(
            data: Data("different".utf8),
            response: HTTPURLResponse(
                url: URL(string: "http://192.168.1.10:48291/v1/media/mediastore-1-43")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
        let downloader = MediaDownloader(session: session, downloadDirectory: directory)

        let results = await downloader.downloadMedia(
            assets: [asset],
            host: "192.168.1.10",
            port: 48291,
            stateStore: store
        )

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(store.record(for: "mediastore-1-43")?.status, .failed)
        XCTAssertEqual(store.record(for: "mediastore-1-43")?.lastErrorCode, "SS-MEDIA-001")
    }

    func testResponseChecksumHeaderIsUsedWhenManifestHashIsMissing() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let data = Data("demo-photo-from-header".utf8)
        let asset = makeAsset(
            assetId: "mediastore-1-44",
            fileName: "IMG_0044.jpg",
            size: Int64(data.count),
            sha256: nil
        )
        let store = InMemoryMediaDownloadStateStore()
        let session = StubMediaDataSession(
            data: data,
            response: HTTPURLResponse(
                url: URL(string: "http://192.168.1.10:48291/v1/media/mediastore-1-44")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["X-ShareSync-SHA256": sha256(data)]
            )!
        )
        let downloader = MediaDownloader(session: session, downloadDirectory: directory)

        let results = await downloader.downloadMedia(
            assets: [asset],
            host: "192.168.1.10",
            port: 48291,
            stateStore: store
        )

        XCTAssertEqual(results.map(\.assetId), ["mediastore-1-44"])
        XCTAssertEqual(store.record(for: "mediastore-1-44")?.status, .downloaded)
    }

    func testDownloadMediaReportsBatchProgress() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstData = Data("first-photo".utf8)
        let firstAsset = makeAsset(
            assetId: "mediastore-1-45",
            fileName: "IMG_0045.jpg",
            size: Int64(firstData.count),
            sha256: sha256(firstData)
        )
        let secondAsset = makeAsset(
            assetId: "mediastore-1-46",
            fileName: "IMG_0046.jpg",
            size: 10,
            sha256: String(repeating: "0", count: 64)
        )
        let store = InMemoryMediaDownloadStateStore()
        let session = StubSequenceMediaDataSession(responses: [
            (
                data: firstData,
                response: HTTPURLResponse(
                    url: URL(string: "http://192.168.1.10:48291/v1/media/mediastore-1-45")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
            (
                data: Data("different".utf8),
                response: HTTPURLResponse(
                    url: URL(string: "http://192.168.1.10:48291/v1/media/mediastore-1-46")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
            ),
        ])
        let downloader = MediaDownloader(session: session, downloadDirectory: directory)

        var progressEvents: [MediaDownloadProgress] = []
        let results = await downloader.downloadMedia(
            assets: [firstAsset, secondAsset],
            host: "192.168.1.10",
            port: 48291,
            stateStore: store,
            progress: { progress in
                progressEvents.append(progress)
            }
        )

        XCTAssertEqual(results.map(\.assetId), ["mediastore-1-45"])
        XCTAssertEqual(progressEvents.last?.totalCount, 2)
        XCTAssertEqual(progressEvents.last?.processedCount, 2)
        XCTAssertEqual(progressEvents.last?.downloadedCount, 1)
        XCTAssertEqual(progressEvents.last?.failedCount, 1)
        XCTAssertEqual(progressEvents.last?.currentAssetId, "mediastore-1-46")
    }

    func testCancellationLeavesItemRetryableWithoutFailure() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let asset = makeAsset(
            assetId: "mediastore-1-47",
            fileName: "IMG_0047.jpg",
            size: 10,
            sha256: nil
        )
        let store = InMemoryMediaDownloadStateStore()
        let session = StubThrowingMediaDataSession(error: CancellationError())
        let downloader = MediaDownloader(session: session, downloadDirectory: directory)

        let results = await downloader.downloadMedia(
            assets: [asset],
            host: "192.168.1.10",
            port: 48291,
            stateStore: store
        )

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(store.record(for: "mediastore-1-47")?.status, .downloading)
        XCTAssertNil(store.record(for: "mediastore-1-47")?.lastErrorCode)
    }

    private func makeAsset(assetId: String, fileName: String, size: Int64, sha256: String?) -> MediaAsset {
        MediaAsset(
            assetId: assetId,
            sourceDeviceId: "android-demo-device",
            mediaType: .photo,
            fileName: fileName,
            mimeType: "image/jpeg",
            size: size,
            sha256: sha256,
            createdAt: nil,
            modifiedAt: nil,
            takenAt: nil,
            width: nil,
            height: nil,
            durationMs: nil,
            relativePath: "DCIM/Camera"
        )
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private final class StubMediaDataSession: MediaDataSession {
    private let data: Data
    private let response: URLResponse
    private(set) var requests: [URLRequest] = []

    init(data: Data, response: URLResponse) {
        self.data = data
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return (data, response)
    }
}

private final class StubSequenceMediaDataSession: MediaDataSession {
    private var responses: [(data: Data, response: URLResponse)]

    init(responses: [(data: Data, response: URLResponse)]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard !responses.isEmpty else {
            throw URLError(.badServerResponse)
        }

        return responses.removeFirst()
    }
}

private final class StubThrowingMediaDataSession: MediaDataSession {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        throw error
    }
}
