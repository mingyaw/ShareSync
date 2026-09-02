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
        case cancelled
        case failed(String)
    }

    struct ManifestSummary: Equatable {
        let sourceDeviceId: String
        let cursor: String
        let photoCount: Int
        let totalBytes: Int64
        let downloadedCount: Int
        let importedCount: Int
        let missingCount: Int
        let failedCount: Int
        let partialCount: Int
        let remainingCount: Int
        let transferStatus: String
        let validationAssetName: String?
        let lastFailureCode: String?
        let lastFailureFileName: String?

    }

    struct SyncResultSummary: Equatable {
        let syncBatchId: String
        let syncedCount: Int
        let skippedCount: Int
        let failedCount: Int
    }

    struct SyncResultReturnSummary: Equatable {
        let status: String
        let httpStatusCode: Int?
    }

    struct DownloadProgressSummary: Equatable {
        let totalCount: Int
        let processedCount: Int
        let downloadedCount: Int
        let failedCount: Int
        let currentFileName: String?

        var progressText: String {
            "\(processedCount)/\(totalCount)"
        }
    }

    @Published var host = ""
    @Published var port = "48291"
    @Published var pairingPayloadText = ""
    @Published private(set) var state: FetchState = .idle
    @Published private(set) var downloadState: DownloadState = .idle
    @Published private(set) var summary: ManifestSummary?
    @Published private(set) var syncResultSummary: SyncResultSummary?
    @Published private(set) var syncResultReturnSummary: SyncResultReturnSummary?
    @Published private(set) var latestSyncResultJSON: String?
    @Published private(set) var downloadProgressSummary: DownloadProgressSummary?
    @Published private(set) var cancellationMessage: String?
    @Published private(set) var pairedDevice: TrustedDevice?
    @Published private(set) var pairingToken: String?
    @Published private(set) var photoLibraryPermissionStatus: PhotoLibraryPermissionStatus = .unknown
    @Published private(set) var localPeerHealth: LocalPeerHealth?

    private let client: ManifestClient
    private let healthClient: HealthClient
    private let downloader: MediaDownloader
    private let photoImporter: PhotoImporter
    private let photoLibraryPermissionChecker: PhotoLibraryPermissionChecking
    private let photoAssetPresenceChecker: PhotoAssetPresenceChecking
    private let downloadStateStore: MediaDownloadStateStore
    private let syncResultStore: SyncResultStore
    private let syncResultClient: SyncResultClient
    private let pairedDeviceSessionStore: PairedDeviceSessionStore
    private let pairingPayloadParser: PairingPayloadParser
    private let photoTransferPlanner = M0PhotoTransferPlanner()
    private var latestManifest: SyncManifest?
    private var activeDownloadTask: Task<Void, Never>?

    init(
        client: ManifestClient = ManifestClient(),
        healthClient: HealthClient = HealthClient(),
        downloader: MediaDownloader = MediaDownloader(),
        photoImporter: PhotoImporter = PhotoKitPhotoImporter(),
        photoLibraryPermissionChecker: PhotoLibraryPermissionChecking = PhotoKitPhotoImporter(),
        photoAssetPresenceChecker: PhotoAssetPresenceChecking = PhotoKitPhotoImporter(),
        pairingPayloadParser: PairingPayloadParser = PairingPayloadParser(),
        downloadStateStore: MediaDownloadStateStore = FileMediaDownloadStateStore(),
        syncResultStore: SyncResultStore = FileSyncResultStore(),
        syncResultClient: SyncResultClient = SyncResultClient(),
        pairedDeviceSessionStore: PairedDeviceSessionStore = FilePairedDeviceSessionStore()
    ) {
        self.client = client
        self.healthClient = healthClient
        self.downloader = downloader
        self.photoImporter = photoImporter
        self.photoLibraryPermissionChecker = photoLibraryPermissionChecker
        self.photoAssetPresenceChecker = photoAssetPresenceChecker
        self.pairingPayloadParser = pairingPayloadParser
        self.downloadStateStore = downloadStateStore
        self.syncResultStore = syncResultStore
        self.syncResultClient = syncResultClient
        self.pairedDeviceSessionStore = pairedDeviceSessionStore
        self.photoLibraryPermissionStatus = photoLibraryPermissionChecker.photoLibraryPermissionStatus()
        restorePairedDeviceSession()
        restoreLatestSyncResult()
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

    var canCancelDownload: Bool {
        downloadState == .downloading
    }

    var isTransferActive: Bool {
        downloadState == .downloading || downloadState == .importing
    }

    var canClearPairing: Bool {
        pairedDevice != nil
            || pairingToken != nil
            || !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !pairingPayloadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                let health = try await healthClient.fetchHealth(from: trimmedHost, port: portNumber)
                localPeerHealth = health
                let manifest = try await client.fetchManifest(
                    from: trimmedHost,
                    port: portNumber,
                    pairingToken: pairingToken
                )
                latestManifest = manifest
                await reconcileMissingPhotoAssets(in: manifest)
                summary = ManifestSummary(manifest: manifest, stateStore: downloadStateStore)
                let publishSummary = await publishSyncResultSummary(
                    for: manifest,
                    host: trimmedHost,
                    port: portNumber
                )
                syncResultSummary = publishSummary.resultSummary
                syncResultReturnSummary = publishSummary.returnSummary
                downloadProgressSummary = nil
                downloadState = .idle
                state = .loaded
            } catch {
                latestManifest = nil
                localPeerHealth = nil
                summary = nil
                syncResultSummary = nil
                syncResultReturnSummary = nil
                downloadProgressSummary = nil
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
            let trustedDevice = TrustedDevice(
                deviceId: payload.deviceId,
                deviceName: payload.deviceName,
                platform: payload.platform,
                publicKey: payload.publicKey,
                pairingToken: payload.pairingToken,
                pairedAt: Date(),
                lastSeenAt: nil,
                trustStatus: .trusted
            )
            pairedDevice = trustedDevice
            pairingToken = payload.pairingToken
            try? pairedDeviceSessionStore.save(
                PairedDeviceSession(
                    host: payload.ip,
                    port: payload.port,
                    device: trustedDevice
                )
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

    func downloadRemainingMedia() {
        guard let manifest = latestManifest else {
            downloadState = .failed("Fetch manifest before downloading.")
            return
        }

        downloadNextMediaBatch(limit: manifest.media.count)
    }

    func cancelDownload() {
        cancelDownload(reason: "Transfer stopped. Completed items are kept; remaining items can be retried.")
    }

    func cancelDownloadForBackground() {
        guard isTransferActive else {
            return
        }

        cancelDownload(reason: "Transfer paused because ShareSync left the foreground. Completed items are kept; retry remaining photos when you return.")
    }

    func resetLocalSyncState() {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        downloadStateStore.clear()
        try? syncResultStore.clear()
        latestManifest = nil
        summary = nil
        syncResultSummary = nil
        syncResultReturnSummary = nil
        latestSyncResultJSON = nil
        downloadProgressSummary = nil
        cancellationMessage = nil
        downloadState = .idle
        state = .idle
    }

    func clearPairing() {
        guard !isTransferActive else {
            return
        }

        try? pairedDeviceSessionStore.clear()
        host = ""
        port = "48291"
        pairingPayloadText = ""
        pairedDevice = nil
        pairingToken = nil
        localPeerHealth = nil
        latestManifest = nil
        summary = nil
        downloadProgressSummary = nil
        syncResultReturnSummary = nil
        cancellationMessage = nil
        downloadState = .idle
        state = .idle
    }

    private func restorePairedDeviceSession() {
        guard let session = try? pairedDeviceSessionStore.load(),
              session.device.trustStatus == .trusted else {
            return
        }

        host = session.host
        port = "\(session.port)"
        pairedDevice = session.device
        pairingToken = session.device.pairingToken
    }

    private func restoreLatestSyncResult() {
        guard let result = try? syncResultStore.latest() else {
            return
        }

        syncResultSummary = SyncResultSummary(result: result)
        latestSyncResultJSON = Self.jsonString(for: result)
        syncResultReturnSummary = SyncResultReturnSummary(status: "Not posted", httpStatusCode: nil)
    }

    private func cancelDownload(reason: String) {
        activeDownloadTask?.cancel()
        activeDownloadTask = nil
        downloadState = .cancelled
        cancellationMessage = reason
        if let latestManifest {
            summary = ManifestSummary(manifest: latestManifest, stateStore: downloadStateStore)
        }
    }

    private func downloadNextMediaBatch(limit: Int) {
        guard let manifest = latestManifest, !manifest.media.isEmpty else {
            downloadState = .failed("Manifest has no photos to download.")
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
        cancellationMessage = nil
        downloadProgressSummary = nil
        activeDownloadTask?.cancel()

        activeDownloadTask = Task {
            let permissionStatus = await photoLibraryPermissionChecker.requestPhotoLibraryPermission()
            photoLibraryPermissionStatus = permissionStatus
            guard permissionStatus.allowsImport else {
                downloadState = .failed("Allow Photos access to import Android photos.")
                activeDownloadTask = nil
                return
            }

            let transferAssets = nextTransferCandidates(in: manifest, limit: limit)
            guard !transferAssets.isEmpty else {
                downloadState = .failed("No remaining photos to download.")
                activeDownloadTask = nil
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
                    stateStore: downloadStateStore,
                    pairingToken: pairingToken,
                    progress: { [weak self] progress in
                        await MainActor.run {
                            self?.downloadProgressSummary = DownloadProgressSummary(progress: progress)
                        }
                    }
                )
            summary = ManifestSummary(manifest: manifest, stateStore: downloadStateStore)
            let postDownloadPublishSummary = await publishSyncResultSummary(
                for: manifest,
                host: trimmedHost,
                port: portNumber
            )
            syncResultSummary = postDownloadPublishSummary.resultSummary
            syncResultReturnSummary = postDownloadPublishSummary.returnSummary

            if Task.isCancelled {
                downloadState = .cancelled
                activeDownloadTask = nil
                return
            }

            importRequests.append(
                contentsOf: results.compactMap { result in
                    guard let asset = transferAssets.first(where: { $0.assetId == result.assetId }) else {
                        return nil
                    }
                    return PhotoImportRequest(
                        sourceAssetId: asset.assetId,
                        sourceHash: asset.sha256,
                        sourceSize: result.downloadedBytes,
                        localFileURL: result.localFileURL,
                        mediaType: asset.mediaType
                    )
                }
            )

            guard !importRequests.isEmpty else {
                let noImportPublishSummary = await publishSyncResultSummary(
                    for: manifest,
                    host: trimmedHost,
                    port: portNumber
                )
                syncResultSummary = noImportPublishSummary.resultSummary
                syncResultReturnSummary = noImportPublishSummary.returnSummary
                downloadProgressSummary = nil
                downloadState = .failed("No photos downloaded.")
                activeDownloadTask = nil
                return
            }

            downloadState = .importing
            let importResults = await photoImporter.importBatch(importRequests)

            if Task.isCancelled {
                summary = ManifestSummary(manifest: manifest, stateStore: downloadStateStore)
                let cancelledPublishSummary = await publishSyncResultSummary(
                    for: manifest,
                    host: trimmedHost,
                    port: portNumber
                )
                syncResultSummary = cancelledPublishSummary.resultSummary
                syncResultReturnSummary = cancelledPublishSummary.returnSummary
                downloadState = .cancelled
                activeDownloadTask = nil
                return
            }

            for importResult in importResults {
                if importResult.status == .synced {
                    removeDownloadedFile(for: importResult.sourceAssetId)
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
            let completedPublishSummary = await publishSyncResultSummary(
                for: manifest,
                host: trimmedHost,
                port: portNumber
            )
            syncResultSummary = completedPublishSummary.resultSummary
            syncResultReturnSummary = completedPublishSummary.returnSummary
            downloadProgressSummary = nil
            downloadState = importResults.contains { $0.status == .synced }
                ? .completed
                : .failed("Downloaded, but photo import failed.")
            activeDownloadTask = nil
        }
    }

    private func removeDownloadedFile(for sourceAssetId: String) {
        guard let localFileURL = downloadStateStore.record(for: sourceAssetId)?.localFileURL else {
            return
        }

        try? FileManager.default.removeItem(at: localFileURL)
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

        if let manifestError = error as? ManifestClientError {
            switch manifestError {
            case .invalidBaseURL:
                return "Android endpoint is not valid."
            case .nonHTTPResponse:
                return "Android did not return a valid local response."
            case .unacceptableStatusCode(401):
                return "Pairing token was rejected. Scan the Android QR code again."
            case .unacceptableStatusCode:
                return "Android rejected the manifest request."
            }
        }

        if let healthError = error as? HealthClientError {
            switch healthError {
            case .invalidBaseURL:
                return "Android endpoint is not valid."
            case .nonHTTPResponse:
                return "Android health check did not return a valid local response."
            case .unacceptableStatusCode:
                return "Android health check was rejected."
            case .peerNotReady:
                return "Android local server is not ready."
            }
        }

        return error.localizedDescription
    }

    private static func jsonString(for result: SyncResult) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func nextTransferCandidate(in manifest: SyncManifest) -> MediaAsset? {
        nextTransferCandidates(in: manifest, limit: 1).first
    }

    private func nextTransferCandidates(in manifest: SyncManifest, limit: Int) -> [MediaAsset] {
        photoTransferPlanner.nextTransferCandidates(
            in: manifest,
            stateStore: downloadStateStore,
            limit: limit
        )
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
            sourceSize: asset.size,
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

    private func publishSyncResultSummary(
        for manifest: SyncManifest,
        host: String,
        port: Int
    ) async -> (resultSummary: SyncResultSummary, returnSummary: SyncResultReturnSummary) {
        let result = SyncResultBuilder().buildMediaResult(
            syncBatchId: "m0-\(manifest.cursor)",
            targetDeviceId: "ios-local",
            records: records(for: manifest)
        )
        try? syncResultStore.save(result)
        latestSyncResultJSON = Self.jsonString(for: result)
        do {
            let statusCode = try await syncResultClient.postSyncResult(
                result,
                to: host,
                port: port,
                pairingToken: pairingToken
            )
            return (
                SyncResultSummary(result: result),
                SyncResultReturnSummary(status: "Posted", httpStatusCode: statusCode)
            )
        } catch {
            return (
                SyncResultSummary(result: result),
                SyncResultReturnSummary(status: "Failed", httpStatusCode: Self.httpStatusCode(from: error))
            )
        }
    }

    private static func httpStatusCode(from error: Error) -> Int? {
        guard let clientError = error as? SyncResultClientError else {
            return nil
        }

        if case .unacceptableStatusCode(let statusCode) = clientError {
            return statusCode
        }

        return nil
    }

    private func records(for manifest: SyncManifest) -> [MediaDownloadRecord] {
        photoTransferPlanner.syncResultRecords(
            in: manifest,
            stateStore: downloadStateStore
        )
    }
}

private extension ManifestFetchViewModel.DownloadProgressSummary {
    init(progress: MediaDownloadProgress) {
        totalCount = progress.totalCount
        processedCount = progress.processedCount
        downloadedCount = progress.downloadedCount
        failedCount = progress.failedCount
        currentFileName = progress.currentFileName
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
        let photoAssets = M0PhotoTransferPlanner().photoAssets(in: manifest)
        sourceDeviceId = manifest.sourceDeviceId
        cursor = manifest.cursor
        photoCount = photoAssets.count
        totalBytes = photoAssets.reduce(0) { $0 + $1.size }
        validationAssetName = photoAssets.first { asset in
            guard let record = stateStore.record(for: asset.assetId) else {
                return true
            }

            return record.status != .imported && record.status != .skipped
        }?.fileName
        downloadedCount = photoAssets.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .downloaded
        }.count
        importedCount = photoAssets.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .imported
        }.count
        missingCount = photoAssets.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .missing
        }.count
        failedCount = photoAssets.filter { asset in
            stateStore.record(for: asset.assetId)?.status == .failed
        }.count
        let manifestAssetIds = Set(photoAssets.map(\.assetId))
        partialCount = stateStore.resumablePartialRecords()
            .filter { record in manifestAssetIds.contains(record.sourceAssetId) }
            .count
        let latestFailedRecord = photoAssets
            .compactMap { asset -> (asset: MediaAsset, record: MediaDownloadRecord)? in
                guard let record = stateStore.record(for: asset.assetId),
                      record.status == .failed else {
                    return nil
                }
                return (asset, record)
            }
            .max { lhs, rhs in lhs.record.updatedAt < rhs.record.updatedAt }
        lastFailureCode = latestFailedRecord?.record.lastErrorCode
        lastFailureFileName = latestFailedRecord?.asset.fileName
        remainingCount = photoAssets.filter { asset in
            guard let record = stateStore.record(for: asset.assetId) else {
                return true
            }

            return record.status == .queued
                || record.status == .downloading
                || record.status == .downloaded
                || record.status == .failed
                || record.status == .missing
        }.count
        if photoCount == 0 {
            transferStatus = "No Photos"
        } else if remainingCount == 0 {
            transferStatus = "Complete"
        } else if failedCount > 0 || missingCount > 0 || partialCount > 0 {
            transferStatus = "Needs Retry"
        } else {
            transferStatus = "Ready"
        }
    }
}
