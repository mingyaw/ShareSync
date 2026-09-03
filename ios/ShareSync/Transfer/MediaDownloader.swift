import CryptoKit
import Foundation

enum MediaDownloaderError: Error, Equatable {
    case invalidMediaURL
    case nonHTTPResponse
    case unacceptableStatusCode(Int, String?)
    case checksumMismatch
    case sizeMismatch(expected: Int64, actual: Int64)
    case invalidPartialResponse
    case insufficientStorage
}

struct MediaDownloadResult: Equatable {
    let assetId: String
    let localFileURL: URL
    let downloadedBytes: Int64
}

struct MediaDownloadProgress: Equatable {
    let totalCount: Int
    let processedCount: Int
    let downloadedCount: Int
    let failedCount: Int
    let currentAssetId: String?
    let currentFileName: String?
}

protocol MediaDataSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: MediaDataSession {}

final class MediaDownloader {
    private let session: MediaDataSession
    private let fileManager: FileManager
    private let downloadDirectory: URL
    private let availableCapacityProvider: (URL) throws -> Int64?
    private let now: () -> Date
    private let requestSigner: RequestSigner

    init(
        session: MediaDataSession = LocalNetworkURLSessionFactory.mediaTransferSession(),
        fileManager: FileManager = .default,
        downloadDirectory: URL? = nil,
        availableCapacityProvider: @escaping (URL) throws -> Int64? = MediaDownloader.availableCapacity,
        now: @escaping () -> Date = Date.init,
        requestSigner: RequestSigner = RequestSigner()
    ) {
        self.session = session
        self.fileManager = fileManager
        self.downloadDirectory = downloadDirectory
            ?? fileManager.temporaryDirectory.appendingPathComponent("ShareSyncDownloads", isDirectory: true)
        self.availableCapacityProvider = availableCapacityProvider
        self.now = now
        self.requestSigner = requestSigner
    }

    func downloadMedia(
        assets: [MediaAsset],
        host: String,
        port: Int,
        stateStore: MediaDownloadStateStore,
        pairingToken: String? = nil,
        signingContext: RequestSigningContext? = nil,
        progress: ((MediaDownloadProgress) async -> Void)? = nil
    ) async -> [MediaDownloadResult] {
        for asset in assets {
            stateStore.upsertQueued(asset: asset, now: now())
        }

        var results: [MediaDownloadResult] = []
        var processedCount = 0
        var failedCount = 0
        await progress?(
            MediaDownloadProgress(
                totalCount: assets.count,
                processedCount: processedCount,
                downloadedCount: results.count,
                failedCount: failedCount,
                currentAssetId: nil,
                currentFileName: nil
            )
        )

        for asset in assets {
            if Task.isCancelled {
                break
            }

            guard let record = stateStore.record(for: asset),
                  record.status == .queued || record.status == .downloading || record.status == .failed else {
                processedCount += 1
                await progress?(
                    MediaDownloadProgress(
                        totalCount: assets.count,
                        processedCount: processedCount,
                        downloadedCount: results.count,
                        failedCount: failedCount,
                        currentAssetId: asset.assetId,
                        currentFileName: asset.fileName
                    )
                )
                continue
            }

            stateStore.markDownloading(sourceAssetId: asset.assetId, downloadedBytes: record.downloadedBytes, now: now())
            if Task.isCancelled {
                break
            }

            await progress?(
                MediaDownloadProgress(
                    totalCount: assets.count,
                    processedCount: processedCount,
                    downloadedCount: results.count,
                    failedCount: failedCount,
                    currentAssetId: asset.assetId,
                    currentFileName: asset.fileName
                )
            )

            do {
                let result = try await downloadWithRetry(
                    asset: asset,
                    host: host,
                    port: port,
                    pairingToken: pairingToken,
                    signingContext: signingContext,
                    resumeRecord: record
                )
                stateStore.markDownloaded(
                    sourceAssetId: asset.assetId,
                    localFileURL: result.localFileURL,
                    downloadedBytes: result.downloadedBytes,
                    now: now()
                )
                results.append(result)
            } catch {
                if Self.isCancellation(error) || Task.isCancelled {
                    break
                }

                failedCount += 1
                stateStore.markFailed(
                    sourceAssetId: asset.assetId,
                    errorCode: errorCode(for: error),
                    now: now()
                )
            }
            processedCount += 1
            await progress?(
                MediaDownloadProgress(
                    totalCount: assets.count,
                    processedCount: processedCount,
                    downloadedCount: results.count,
                    failedCount: failedCount,
                    currentAssetId: asset.assetId,
                    currentFileName: asset.fileName
                )
            )
        }

        return results
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }

        return false
    }

    private func download(
        asset: MediaAsset,
        host: String,
        port: Int,
        pairingToken: String?,
        signingContext: RequestSigningContext?,
        resumeRecord: MediaDownloadRecord?
    ) async throws -> MediaDownloadResult {
        guard let url = mediaURL(assetId: asset.assetId, host: host, port: port) else {
            throw MediaDownloaderError.invalidMediaURL
        }

        var request = URLRequest(url: url)
        if let pairingToken, !pairingToken.isEmpty {
            request.setValue(pairingToken, forHTTPHeaderField: "X-ShareSync-Pairing-Token")
        }
        if let signingContext {
            requestSigner.sign(request: &request, context: signingContext)
        }
        let resume = resumablePrefix(for: resumeRecord)
        if resume.downloadedBytes > 0 {
            request.setValue("bytes=\(resume.downloadedBytes)-", forHTTPHeaderField: "Range")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MediaDownloaderError.nonHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MediaDownloaderError.unacceptableStatusCode(
                httpResponse.statusCode,
                serverErrorCode(from: data)
            )
        }

        let finalData: Data
        if resume.downloadedBytes > 0 && httpResponse.statusCode == 206 {
            guard partialResponseMatchesResume(httpResponse, resumeOffset: resume.downloadedBytes, totalBytes: asset.size) else {
                throw MediaDownloaderError.invalidPartialResponse
            }
            finalData = resume.data + data
        } else {
            finalData = data
        }
        let responseHash = httpResponse.value(forHTTPHeaderField: "X-ShareSync-SHA256")
        let expectedHash = firstNonEmpty(asset.sha256, responseHash)
        if let expectedHash {
            let digest = SHA256.hash(data: finalData)
                .map { String(format: "%02x", $0) }
                .joined()
            guard digest.caseInsensitiveCompare(expectedHash) == .orderedSame else {
                throw MediaDownloaderError.checksumMismatch
            }
        }
        guard Int64(finalData.count) == asset.size else {
            throw MediaDownloaderError.sizeMismatch(expected: asset.size, actual: Int64(finalData.count))
        }

        try fileManager.createDirectory(at: downloadDirectory, withIntermediateDirectories: true)
        let destination = downloadDirectory.appendingPathComponent(localFileName(for: asset), isDirectory: false)
        try ensureEnoughStorage(for: finalData.count, at: destination)
        try finalData.write(to: destination, options: [.atomic])

        return MediaDownloadResult(
            assetId: asset.assetId,
            localFileURL: destination,
            downloadedBytes: Int64(finalData.count)
        )
    }

    private func downloadWithRetry(
        asset: MediaAsset,
        host: String,
        port: Int,
        pairingToken: String?,
        signingContext: RequestSigningContext?,
        resumeRecord: MediaDownloadRecord?
    ) async throws -> MediaDownloadResult {
        do {
            return try await download(
                asset: asset,
                host: host,
                port: port,
                pairingToken: pairingToken,
                signingContext: signingContext,
                resumeRecord: resumeRecord
            )
        } catch {
            guard Self.shouldRetryDownload(error) else {
                throw error
            }

            return try await download(
                asset: asset,
                host: host,
                port: port,
                pairingToken: pairingToken,
                signingContext: signingContext,
                resumeRecord: resumeRecord
            )
        }
    }

    private func resumablePrefix(for record: MediaDownloadRecord?) -> (data: Data, downloadedBytes: Int64) {
        guard let record,
              record.downloadedBytes > 0,
              let localFileURL = record.localFileURL,
              fileManager.fileExists(atPath: localFileURL.path),
              let data = try? Data(contentsOf: localFileURL),
              !data.isEmpty else {
            return (Data(), 0)
        }

        let downloadedBytes = min(Int64(data.count), record.downloadedBytes)
        return (data.prefix(Int(downloadedBytes)), downloadedBytes)
    }

    private static func shouldRetryDownload(_ error: Error) -> Bool {
        if case MediaDownloaderError.checksumMismatch = error {
            return true
        }
        if case MediaDownloaderError.sizeMismatch = error {
            return true
        }

        guard let urlError = error as? URLError else {
            return false
        }

        switch urlError.code {
        case .cannotConnectToHost, .networkConnectionLost, .timedOut:
            return true
        default:
            return false
        }
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

    private func firstNonEmpty(_ values: String?...) -> String? {
        values.first { value in
            guard let value else {
                return false
            }
            return !value.isEmpty
        } ?? nil
    }

    private func errorCode(for error: Error) -> String {
        if let downloaderError = error as? MediaDownloaderError {
            switch downloaderError {
            case .invalidMediaURL:
                return "SS-REQ-001"
            case .nonHTTPResponse:
                return "SS-NET-001"
            case .unacceptableStatusCode(let statusCode, let serverErrorCode):
                if let serverErrorCode, !serverErrorCode.isEmpty {
                    return serverErrorCode
                }
                if statusCode == 404 {
                    return "SS-MEDIA-404"
                }
                if statusCode == 401 {
                    return "SS-AUTH-001"
                }
                return "SS-NET-002"
            case .checksumMismatch:
                return "SS-MEDIA-001"
            case .sizeMismatch:
                return "SS-MEDIA-004"
            case .invalidPartialResponse:
                return "SS-MEDIA-003"
            case .insufficientStorage:
                return "SS-STORE-001"
            }
        }

        if error is URLError {
            return "SS-NET-002"
        }

        return "SS-MEDIA-999"
    }

    private func serverErrorCode(from data: Data) -> String? {
        try? JSONDecoder().decode(ServerErrorEnvelope.self, from: data).errorCode
    }

    private func partialResponseMatchesResume(
        _ response: HTTPURLResponse,
        resumeOffset: Int64,
        totalBytes: Int64
    ) -> Bool {
        guard let contentRange = response.value(forHTTPHeaderField: "Content-Range"),
              let parsed = ContentRange(contentRange) else {
            return false
        }

        return parsed.start == resumeOffset && parsed.totalBytes == totalBytes
    }

    private func ensureEnoughStorage(for bytes: Int, at destination: URL) throws {
        guard let availableBytes = try availableCapacityProvider(destination) else {
            return
        }

        if availableBytes < Int64(bytes) {
            throw MediaDownloaderError.insufficientStorage
        }
    }

    private static func availableCapacity(for destination: URL) throws -> Int64? {
        let values = try destination.deletingLastPathComponent().resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        )
        return values.volumeAvailableCapacityForImportantUsage
    }
}

private struct ServerErrorEnvelope: Decodable {
    let errorCode: String
}

private struct ContentRange {
    let start: Int64
    let endInclusive: Int64
    let totalBytes: Int64

    init?(_ value: String) {
        guard value.hasPrefix("bytes ") else {
            return nil
        }

        let rangeAndTotal = value.dropFirst("bytes ".count)
        let parts = rangeAndTotal.split(separator: "/", maxSplits: 1)
        guard parts.count == 2,
              let totalBytes = Int64(parts[1]) else {
            return nil
        }

        let rangeParts = parts[0].split(separator: "-", maxSplits: 1)
        guard rangeParts.count == 2,
              let start = Int64(rangeParts[0]),
              let endInclusive = Int64(rangeParts[1]),
              start <= endInclusive,
              totalBytes > 0,
              endInclusive < totalBytes else {
            return nil
        }

        self.start = start
        self.endInclusive = endInclusive
        self.totalBytes = totalBytes
    }
}
