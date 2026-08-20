import CryptoKit
import Foundation

enum MediaDownloaderError: Error, Equatable {
    case invalidMediaURL
    case nonHTTPResponse
    case unacceptableStatusCode(Int)
    case checksumMismatch
}

struct MediaDownloadResult: Equatable {
    let assetId: String
    let localFileURL: URL
    let downloadedBytes: Int64
}

protocol MediaDataSession {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: MediaDataSession {}

final class MediaDownloader {
    private let session: MediaDataSession
    private let fileManager: FileManager
    private let downloadDirectory: URL
    private let now: () -> Date

    init(
        session: MediaDataSession = URLSession.shared,
        fileManager: FileManager = .default,
        downloadDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.session = session
        self.fileManager = fileManager
        self.downloadDirectory = downloadDirectory
            ?? fileManager.temporaryDirectory.appendingPathComponent("ShareSyncDownloads", isDirectory: true)
        self.now = now
    }

    func downloadMedia(
        assets: [MediaAsset],
        host: String,
        port: Int,
        stateStore: MediaDownloadStateStore
    ) async -> [MediaDownloadResult] {
        for asset in assets {
            stateStore.upsertQueued(asset: asset, now: now())
        }

        var results: [MediaDownloadResult] = []
        for asset in assets {
            guard let record = stateStore.record(for: asset.assetId),
                  record.status == .queued || record.status == .downloading || record.status == .failed else {
                continue
            }

            stateStore.markDownloading(sourceAssetId: asset.assetId, downloadedBytes: record.downloadedBytes, now: now())

            do {
                let result = try await download(asset: asset, host: host, port: port)
                stateStore.markDownloaded(
                    sourceAssetId: asset.assetId,
                    localFileURL: result.localFileURL,
                    downloadedBytes: result.downloadedBytes,
                    now: now()
                )
                results.append(result)
            } catch {
                stateStore.markFailed(
                    sourceAssetId: asset.assetId,
                    errorCode: errorCode(for: error),
                    now: now()
                )
            }
        }

        return results
    }

    private func download(asset: MediaAsset, host: String, port: Int) async throws -> MediaDownloadResult {
        guard let url = mediaURL(assetId: asset.assetId, host: host, port: port) else {
            throw MediaDownloaderError.invalidMediaURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MediaDownloaderError.nonHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MediaDownloaderError.unacceptableStatusCode(httpResponse.statusCode)
        }

        if let expectedHash = asset.sha256, !expectedHash.isEmpty {
            let digest = SHA256.hash(data: data)
                .map { String(format: "%02x", $0) }
                .joined()
            guard digest.caseInsensitiveCompare(expectedHash) == .orderedSame else {
                throw MediaDownloaderError.checksumMismatch
            }
        }

        try fileManager.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        let destination = downloadDirectory.appendingPathComponent(localFileName(for: asset), isDirectory: false)
        try data.write(to: destination, options: [.atomic])

        return MediaDownloadResult(
            assetId: asset.assetId,
            localFileURL: destination,
            downloadedBytes: Int64(data.count)
        )
    }

    private func mediaURL(assetId: String, host: String, port: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/v1/media/\(assetId)"
        return components.url
    }

    private func localFileName(for asset: MediaAsset) -> String {
        let extensionPart = URL(fileURLWithPath: asset.fileName).pathExtension
        let safeAssetId = asset.assetId.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "-"
        }
        let baseName = String(safeAssetId)
        return extensionPart.isEmpty ? baseName : "\(baseName).\(extensionPart)"
    }

    private func errorCode(for error: Error) -> String {
        if let downloaderError = error as? MediaDownloaderError {
            switch downloaderError {
            case .invalidMediaURL:
                return "SS-REQ-001"
            case .nonHTTPResponse:
                return "SS-NET-001"
            case .unacceptableStatusCode:
                return "SS-NET-002"
            case .checksumMismatch:
                return "SS-DATA-001"
            }
        }

        if error is URLError {
            return "SS-NET-002"
        }

        return "SS-DATA-002"
    }
}
