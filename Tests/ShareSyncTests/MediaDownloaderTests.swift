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
        XCTAssertEqual(session.requestedURLs.map(\.path), ["/v1/media/mediastore-1-42"])
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
        XCTAssertEqual(store.record(for: "mediastore-1-43")?.lastErrorCode, "SS-DATA-001")
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
    private(set) var requestedURLs: [URL] = []

    init(data: Data, response: URLResponse) {
        self.data = data
        self.response = response
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        requestedURLs.append(url)
        return (data, response)
    }
}
