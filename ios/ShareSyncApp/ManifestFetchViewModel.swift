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
        let failedCount: Int
        let validationAssetName: String?

        var totalItems: Int {
            photoCount + videoCount
        }
    }

    @Published var host = ""
    @Published var port = "48291"
    @Published private(set) var state: FetchState = .idle
    @Published private(set) var downloadState: DownloadState = .idle
    @Published private(set) var summary: ManifestSummary?

    private let client: ManifestClient
    private let downloader: MediaDownloader
    private let photoImporter: PhotoImporter
    private let downloadStateStore: MediaDownloadStateStore
    private var latestManifest: SyncManifest?

    init(
        client: ManifestClient = ManifestClient(),
        downloader: MediaDownloader = MediaDownloader(),
        photoImporter: PhotoImporter = PhotoKitPhotoImporter(),
        downloadStateStore: MediaDownloadStateStore = InMemoryMediaDownloadStateStore()
    ) {
        self.client = client
        self.downloader = downloader
        self.photoImporter = photoImporter
        self.downloadStateStore = downloadStateStore
    }

    var canFetch: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Int(port) != nil && state != .loading
    }

    var canDownload: Bool {
        latestManifest?.media.isEmpty == false && downloadState != .downloading
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
                summary = ManifestSummary(manifest: manifest, stateStore: downloadStateStore)
                downloadState = .idle
                state = .loaded
            } catch {
                latestManifest = nil
                summary = nil
                state = .failed(Self.message(for: error))
            }
        }
    }

    func downloadFirstMedia() {
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
            let validationAssets = Array(manifest.media.prefix(1))
            let results = await downloader.downloadMedia(
                assets: validationAssets,
                host: trimmedHost,
                port: portNumber,
                stateStore: downloadStateStore
            )
            summary = ManifestSummary(manifest: manifest, stateStore: downloadStateStore)
            guard !results.isEmpty else {
                downloadState = .failed("No media downloaded.")
                return
            }

            downloadState = .importing
            let importResults = await photoImporter.importBatch(
                results.compactMap { result in
                    guard let asset = validationAssets.first(where: { $0.assetId == result.assetId }) else {
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

            for importResult in importResults {
                if importResult.status == .synced {
                    downloadStateStore.markImported(sourceAssetId: importResult.sourceAssetId, now: Date())
                } else {
                    downloadStateStore.markFailed(
                        sourceAssetId: importResult.sourceAssetId,
                        errorCode: importResult.errorCode ?? "SS-PHOTO-002",
                        now: Date()
                    )
                }
            }

            summary = ManifestSummary(manifest: manifest, stateStore: downloadStateStore)
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
}

private extension ManifestFetchViewModel.ManifestSummary {
    init(manifest: SyncManifest, stateStore: MediaDownloadStateStore) {
        sourceDeviceId = manifest.sourceDeviceId
        cursor = manifest.cursor
        photoCount = manifest.media.filter { $0.mediaType == .photo }.count
        videoCount = manifest.media.filter { $0.mediaType == .video }.count
        totalBytes = manifest.media.reduce(0) { $0 + $1.size }
        validationAssetName = manifest.media.first?.fileName
        downloadedCount = manifest.media.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .downloaded
        }.count
        importedCount = manifest.media.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .imported
        }.count
        failedCount = manifest.media.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .failed
        }.count
    }
}
