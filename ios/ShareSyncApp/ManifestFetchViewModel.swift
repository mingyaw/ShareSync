import Foundation

@MainActor
final class ManifestFetchViewModel: ObservableObject {
    enum FetchState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum DownloadState: Equatable {
        case idle
        case downloading
        case importing
        case completed
        case failed(String)
    }

    struct ManifestSummary: Equatable {
        let sourceDeviceId: String
        let cursor: String
        let photoCount: Int
        let videoCount: Int
        let totalBytes: Int64
        let downloadedCount: Int
        let importedCount: Int
        let missingCount: Int
        let failedCount: Int
        let validationAssetName: String?

        var totalItems: Int {
            photoCount + videoCount
        }
    }

    struct SyncResultSummary: Equatable {
        let syncBatchId: String
        let syncedCount: Int
        let skippedCount: Int
        let failedCount: Int
    }

    @Published var host = ""
    @Published var port = "48291"
    @Published var pairingPayloadText = ""
    @Published private(set) var state: FetchState = .idle
    @Published private(set) var downloadState: DownloadState = .idle
    @Published private(set) var summary: ManifestSummary?
    @Published private(set) var syncResultSummary: SyncResultSummary?
    @Published private(set) var pairedDevice: TrustedDevice?

    private let client: ManifestClient
    private let downloader: MediaDownloader
    private let photoImporter: PhotoImporter
    private let photoAssetPresenceChecker: PhotoAssetPresenceChecking
    private let downloadStateStore: MediaDownloadStateStore
    private let pairingPayloadParser: PairingPayloadParser
    private var latestManifest: SyncManifest?

    init(
        client: ManifestClient = ManifestClient(),
        downloader: MediaDownloader = MediaDownloader(),
        photoImporter: PhotoImporter = PhotoKitPhotoImporter(),
        photoAssetPresenceChecker: PhotoAssetPresenceChecking = PhotoKitPhotoImporter(),
        pairingPayloadParser: PairingPayloadParser = PairingPayloadParser(),
        downloadStateStore: MediaDownloadStateStore = FileMediaDownloadStateStore()
    ) {
        self.client = client
        self.downloader = downloader
        self.photoImporter = photoImporter
        self.photoAssetPresenceChecker = photoAssetPresenceChecker
        self.pairingPayloadParser = pairingPayloadParser
        self.downloadStateStore = downloadStateStore
    }

    var canFetch: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Int(port) != nil && state != .loading
    }

    var canDownload: Bool {
        guard let latestManifest else {
            return false
        }

        return nextTransferCandidate(in: latestManifest) != nil
            && downloadState != .downloading
            && downloadState != .importing
    }

    func fetchManifest() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            state = .failed("Enter Android IP address.")
            return
        }

        guard let portNumber = Int(port), (1...65535).contains(portNumber) else {
            state = .failed("Enter a valid port.")
            return
        }

        state = .loading

        Task {
            do {
                let manifest = try await client.fetchManifest(from: trimmedHost, port: portNumber)
                latestManifest = manifest
                await reconcileMissingPhotoAssets(in: manifest)
                summary = ManifestSummary(manifest: manifest, stateStore: downloadStateStore)
                syncResultSummary = makeSyncResultSummary(for: manifest)
                downloadState = .idle
                state = .loaded
            } catch {
                latestManifest = nil
                summary = nil
                syncResultSummary = nil
                state = .failed(Self.message(for: error))
            }
        }
    }

    func applyPairingPayload() {
        let trimmedPayload = pairingPayloadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmedPayload.data(using: .utf8), !data.isEmpty else {
            state = .failed("Paste the Android pairing payload.")
            return
        }

        do {
            let payload = try pairingPayloadParser.parse(data)
            host = payload.ip
            port = "\(payload.port)"
            pairedDevice = TrustedDevice(
                deviceId: payload.deviceId,
                deviceName: payload.deviceName,
                platform: payload.platform,
                publicKey: payload.publicKey,
                pairedAt: Date(),
                lastSeenAt: nil,
                trustStatus: .trusted
            )
            state = .idle
        } catch PairingPayloadParserError.expired {
            state = .failed("Pairing payload expired. Generate a new one on Android.")
        } catch {
            state = .failed("Pairing payload is not valid.")
        }
    }

    func downloadFirstMedia() {
        downloadNextMediaBatch(limit: 1)
    }

    func downloadSmallMediaBatch() {
        downloadNextMediaBatch(limit: 5)
    }

    private func downloadNextMediaBatch(limit: Int) {
        guard let manifest = latestManifest, !manifest.media.isEmpty else {
            downloadState = .failed("Manifest has no media to download.")
            return
        }

        guard let portNumber = Int(port), (1...65535).contains(portNumber) else {
            downloadState = .failed("Enter a valid port.")
            return
        }

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            downloadState = .failed("Enter Android IP address.")
            return
        }

        downloadState = .downloading

        Task {
            let transferAssets = nextTransferCandidates(in: manifest, limit: limit)
            guard !transferAssets.isEmpty else {
                downloadState = .failed("No remaining media to download.")
                return
            }

            var importRequests: [PhotoImportRequest] = []
            var assetsToDownload: [MediaAsset] = []

            for asset in transferAssets {
                if let downloadedRequest = downloadedImportRequest(for: asset) {
                    importRequests.append(downloadedRequest)
                } else {
                    assetsToDownload.append(asset)
                }
            }

            let results = assetsToDownload.isEmpty
                ? []
                : await downloader.downloadMedia(
                    assets: assetsToDownload,
                    host: trimmedHost,
                    port: portNumber,
                    stateStore: downloadStateStore
                )
            summary = ManifestSummary(manifest: manifest, stateStore: downloadStateStore)
            syncResultSummary = makeSyncResultSummary(for: manifest)

            importRequests.append(
                contentsOf: results.compactMap { result in
                    guard let asset = transferAssets.first(where: { $0.assetId == result.assetId }) else {
                        return nil
                    }
                    return PhotoImportRequest(
                        sourceAssetId: asset.assetId,
                        sourceHash: asset.sha256,
                        localFileURL: result.localFileURL,
                        mediaType: asset.mediaType
                    )
                }
            )

            guard !importRequests.isEmpty else {
                syncResultSummary = makeSyncResultSummary(for: manifest)
                downloadState = .failed("No media downloaded.")
                return
            }

            downloadState = .importing
            let importResults = await photoImporter.importBatch(importRequests)

            for importResult in importResults {
                if importResult.status == .synced {
                    downloadStateStore.markImported(
                        sourceAssetId: importResult.sourceAssetId,
                        photoLocalIdentifier: importResult.localIdentifier,
                        now: Date()
                    )
                } else {
                    downloadStateStore.markFailed(
                        sourceAssetId: importResult.sourceAssetId,
                        errorCode: importResult.errorCode ?? "SS-MEDIA-999",
                        now: Date()
                    )
                }
            }

            summary = ManifestSummary(manifest: manifest, stateStore: downloadStateStore)
            syncResultSummary = makeSyncResultSummary(for: manifest)
            downloadState = importResults.contains { $0.status == .synced }
                ? .completed
                : .failed("Downloaded, but photo import failed.")
        }
    }

    private static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .networkConnectionLost, .timedOut:
                return "Cannot reach Android phone on local network."
            case .notConnectedToInternet:
                return "Local network is unavailable."
            case .appTransportSecurityRequiresSecureConnection:
                return "Local HTTP is blocked by iOS settings."
            default:
                return urlError.localizedDescription
            }
        }

        if error is DecodingError {
            return "Android manifest format is not supported."
        }

        return error.localizedDescription
    }

    private func nextTransferCandidate(in manifest: SyncManifest) -> MediaAsset? {
        nextTransferCandidates(in: manifest, limit: 1).first
    }

    private func nextTransferCandidates(in manifest: SyncManifest, limit: Int) -> [MediaAsset] {
        guard limit > 0 else {
            return []
        }

        return Array(manifest.media.lazy.filter { asset in
            guard let record = self.downloadStateStore.record(for: asset.assetId) else {
                return true
            }

            return record.status == .queued
                || record.status == .downloading
                || record.status == .downloaded
                || record.status == .failed
        }.prefix(limit))
    }

    private func downloadedImportRequest(for asset: MediaAsset) -> PhotoImportRequest? {
        guard let record = downloadStateStore.record(for: asset.assetId),
              record.status == .downloaded else {
            return nil
        }

        guard let localFileURL = record.localFileURL,
              FileManager.default.fileExists(atPath: localFileURL.path) else {
            downloadStateStore.markFailed(
                sourceAssetId: asset.assetId,
                errorCode: "SS-NET-002",
                now: Date()
            )
            return nil
        }

        return PhotoImportRequest(
            sourceAssetId: asset.assetId,
            sourceHash: asset.sha256,
            localFileURL: localFileURL,
            mediaType: asset.mediaType
        )
    }

    private func reconcileMissingPhotoAssets(in manifest: SyncManifest) async {
        for asset in manifest.media {
            guard let record = downloadStateStore.record(for: asset.assetId),
                  record.status == .imported,
                  let photoLocalIdentifier = record.photoLocalIdentifier,
                  !photoLocalIdentifier.isEmpty else {
                continue
            }

            do {
                let exists = try await photoAssetPresenceChecker.assetExists(localIdentifier: photoLocalIdentifier)
                if !exists {
                    downloadStateStore.markMissing(sourceAssetId: asset.assetId, now: Date())
                }
            } catch {
                continue
            }
        }
    }

    private func makeSyncResultSummary(for manifest: SyncManifest) -> SyncResultSummary {
        let result = SyncResultBuilder().buildMediaResult(
            syncBatchId: "m0-\(manifest.cursor)",
            targetDeviceId: "ios-local",
            records: records(for: manifest)
        )
        return SyncResultSummary(result: result)
    }

    private func records(for manifest: SyncManifest) -> [MediaDownloadRecord] {
        let sourceAssetIds = Set(manifest.media.map(\.assetId))
        return downloadStateStore.allRecords().filter { record in
            sourceAssetIds.contains(record.sourceAssetId)
        }
    }
}

private extension ManifestFetchViewModel.SyncResultSummary {
    init(result: SyncResult) {
        syncBatchId = result.syncBatchId
        syncedCount = result.results.filter { $0.status == .synced }.count
        skippedCount = result.results.filter { $0.status == .skipped }.count
        failedCount = result.results.filter { $0.status == .failed }.count
    }
}

private extension ManifestFetchViewModel.ManifestSummary {
    init(manifest: SyncManifest, stateStore: MediaDownloadStateStore) {
        sourceDeviceId = manifest.sourceDeviceId
        cursor = manifest.cursor
        photoCount = manifest.media.filter { $0.mediaType == .photo }.count
        videoCount = manifest.media.filter { $0.mediaType == .video }.count
        totalBytes = manifest.media.reduce(0) { $0 + $1.size }
        validationAssetName = manifest.media.first { asset in
            guard let record = stateStore.record(for: asset.assetId) else {
                return true
            }

            return record.status != .imported && record.status != .skipped
        }?.fileName
        downloadedCount = manifest.media.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .downloaded
        }.count
        importedCount = manifest.media.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .imported
        }.count
        missingCount = manifest.media.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .missing
        }.count
        failedCount = manifest.media.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .failed
        }.count
    }
}
