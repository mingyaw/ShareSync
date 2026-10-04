import Foundation

@MainActor
final class MacPhotoSyncViewModel: ObservableObject {
    struct BatchProgress: Equatable {
        let totalCount: Int
        let completedCount: Int
        let failedCount: Int
        let currentFileName: String?

        var processedCount: Int { completedCount + failedCount }
    }

    enum CompletionReturnState: Equatable {
        case none
        case delivered(Date)
        case pendingRetry(Date, String)
    }

    enum Phase: Equatable {
        case ready
        case connecting
        case loadingPhotos
        case downloading
        case importing
        case completed
        case failed(String)
    }

    enum NoteSyncState: Equatable {
        case idle
        case syncing
        case completed(Date, changedCount: Int, conflictCount: Int)
        case failed(String)
    }

    @Published var pairingPayload = ""
    @Published var host = ""
    @Published var port = "48291"
    @Published private(set) var pairingQRCodePayload: String?
    @Published private(set) var nearbyAndroidDevices: [NearbyAndroidDevice] = []
    @Published private(set) var selectedNearbyAndroidDeviceID: String?
    @Published private(set) var isDiscoveringNearbyDevices = false
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var pairedDevice: TrustedDevice?
    @Published private(set) var manifest: SyncManifest?
    @Published private(set) var lastSyncedFileName: String?
    @Published private(set) var progress: MediaDownloadProgress?
    @Published private(set) var batchProgress: BatchProgress?
    @Published private(set) var completionReturnState: CompletionReturnState = .none
    @Published private(set) var recentSyncHistory: [SyncHistorySummary] = []
    @Published private(set) var noteSyncState: NoteSyncState = .idle
    @Published private(set) var noteCount = 0
    @Published private(set) var notes: [VersionedNote] = []
    @Published private(set) var noteMutationError: String?
    @Published var keepRunning: Bool {
        didSet { defaults.set(keepRunning, forKey: MacPreferenceKeys.keepRunning) }
    }
    @Published var automaticSyncEnabled: Bool {
        didSet {
            defaults.set(automaticSyncEnabled, forKey: MacPreferenceKeys.automaticSync)
            restartScheduledSync()
        }
    }
    @Published var scheduledSyncIntervalMinutes: Int {
        didSet {
            defaults.set(scheduledSyncIntervalMinutes, forKey: MacPreferenceKeys.syncIntervalMinutes)
            restartScheduledSync()
        }
    }
    @Published var scheduledBatchLimit: Int {
        didSet { defaults.set(scheduledBatchLimit, forKey: MacPreferenceKeys.batchLimit) }
    }
    @Published var automaticNoteSyncEnabled: Bool {
        didSet { defaults.set(automaticNoteSyncEnabled, forKey: MacPreferenceKeys.automaticNoteSync) }
    }
    @Published private(set) var nextScheduledSyncAt: Date?

    private let manifestClient: ManifestClient
    private let healthClient: HealthClient
    private let downloader: MediaDownloader
    private let importer: PhotoKitPhotoImporter
    private let stateStore: MediaDownloadStateStore
    private let sessionStore: PairedDeviceSessionStore
    private let resultStore: SyncResultStore
    private let resultClient: SyncResultClient
    private let deviceUnregistrationClient: DeviceUnregistrationClient
    private let syncEventStore: SyncEventStore
    private let noteSyncClient: NoteSyncClient
    private let noteRepository: NoteRepository
    private let discovery: LocalPeerDiscovery
    private let nearbyDiscovery: NearbyPeerDiscovery
    private let endpointResolver: PairedEndpointResolver
    private let targetDeviceId: String
    private let pairingListener: MacPairingListener
    private let defaults: UserDefaults
    private let planner = M0PhotoTransferPlanner()
    private var pairingToken: String?
    private var syncTask: Task<Void, Never>?
    private var noteSyncTask: Task<Void, Never>?
    private var scheduledSyncTask: Task<Void, Never>?
    private var nearbyDiscoveryTask: Task<Void, Never>?
    private var pairingSetupTask: Task<Void, Never>?

    init(
        manifestClient: ManifestClient = ManifestClient(),
        healthClient: HealthClient = HealthClient(),
        downloader: MediaDownloader = MediaDownloader(),
        importer: PhotoKitPhotoImporter = PhotoKitPhotoImporter(),
        stateStore: MediaDownloadStateStore = FileMediaDownloadStateStore(),
        sessionStore: PairedDeviceSessionStore = FilePairedDeviceSessionStore(),
        resultStore: SyncResultStore = FileSyncResultStore(),
        resultClient: SyncResultClient = SyncResultClient(),
        deviceUnregistrationClient: DeviceUnregistrationClient = DeviceUnregistrationClient(),
        syncEventStore: SyncEventStore = FileSyncEventStore(),
        noteSyncClient: NoteSyncClient = NoteSyncClient(),
        noteRepository: NoteRepository? = nil,
        discovery: LocalPeerDiscovery? = nil,
        nearbyDiscovery: NearbyPeerDiscovery? = nil,
        endpointResolver: PairedEndpointResolver = PairedEndpointResolver(),
        targetDeviceId: String = MacDeviceIdentity.persistentID(),
        pairingListener: MacPairingListener = MacPairingListener(),
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.keepRunning = defaults.object(forKey: MacPreferenceKeys.keepRunning) as? Bool ?? true
        self.automaticSyncEnabled = defaults.object(forKey: MacPreferenceKeys.automaticSync) as? Bool ?? false
        let storedInterval = defaults.object(forKey: MacPreferenceKeys.syncIntervalMinutes) as? Int ?? 15
        self.scheduledSyncIntervalMinutes = [5, 15, 30, 60].contains(storedInterval) ? storedInterval : 15
        let storedBatchLimit = defaults.object(forKey: MacPreferenceKeys.batchLimit) as? Int ?? 50
        self.scheduledBatchLimit = [0, 25, 50, 100].contains(storedBatchLimit) ? storedBatchLimit : 50
        self.automaticNoteSyncEnabled = defaults.object(forKey: MacPreferenceKeys.automaticNoteSync) as? Bool ?? true
        self.manifestClient = manifestClient
        self.healthClient = healthClient
        self.downloader = downloader
        self.importer = importer
        self.stateStore = stateStore
        self.sessionStore = sessionStore
        self.resultStore = resultStore
        self.resultClient = resultClient
        self.deviceUnregistrationClient = deviceUnregistrationClient
        self.syncEventStore = syncEventStore
        self.noteSyncClient = noteSyncClient
        self.discovery = discovery ?? BonjourLocalPeerDiscovery()
        self.nearbyDiscovery = nearbyDiscovery ?? BonjourNearbyPeerDiscovery()
        self.endpointResolver = endpointResolver
        self.targetDeviceId = targetDeviceId
        self.noteRepository = noteRepository ?? Self.makeNoteRepository(deviceID: targetDeviceId)
        self.pairingListener = pairingListener
        restorePairing()
        restoreSyncHistory()
        refreshNoteCount()
        restartScheduledSync()
    }

    var isPaired: Bool { pairedDevice != nil }
    var isNoteSyncing: Bool { noteSyncState == .syncing }
    var isBusy: Bool {
        switch phase {
        case .connecting, .loadingPhotos, .downloading, .importing:
            return true
        default:
            return false
        }
    }

    var canCancel: Bool {
        switch phase {
        case .connecting, .loadingPhotos, .downloading:
            return true
        case .ready, .importing, .completed, .failed:
            return false
        }
    }

    var menuBarSymbol: String {
        switch phase {
        case .failed: return "exclamationmark.arrow.triangle.2.circlepath"
        case .connecting, .loadingPhotos, .downloading, .importing: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .ready: return isPaired ? "arrow.left.arrow.right.circle.fill" : "qrcode"
        }
    }

    var photoCount: Int {
        manifest.map { planner.photoAssets(in: $0).count } ?? 0
    }

    var importedCount: Int {
        stateStore.allRecords().filter { $0.status == .imported }.count
    }

    var remainingCount: Int {
        guard let manifest else { return 0 }
        return planner.nextTransferCandidates(
            in: manifest,
            stateStore: stateStore,
            limit: Int.max
        ).count
    }

    var statusTitle: String {
        switch phase {
        case .ready:
            return isPaired ? text("mac.status.ready") : text("mac.status.pairing_required")
        case .connecting:
            return text("mac.status.connecting")
        case .loadingPhotos:
            return text("mac.status.loading")
        case .downloading:
            return text("mac.status.downloading")
        case .importing:
            return text("mac.status.importing")
        case .completed:
            return text("mac.status.completed")
        case .failed:
            return text("mac.status.attention")
        }
    }

    var statusDetail: String {
        switch phase {
        case .ready where pairedDevice == nil:
            return text("mac.status.pairing_detail")
        case .ready:
            return String(format: text("mac.status.ready_detail"), pairedDevice?.deviceName ?? "Android")
        case .connecting:
            return text("mac.status.connecting_detail")
        case .loadingPhotos:
            return text("mac.status.loading_detail")
        case .downloading:
            return progress?.currentFileName ?? text("mac.status.downloading_detail")
        case .importing:
            return text("mac.status.importing_detail")
        case .completed:
            return lastSyncedFileName.map { String(format: text("mac.status.completed_detail"), $0) }
                ?? text("mac.status.completed")
        case .failed(let message):
            return message
        }
    }

    var failureMessage: String? {
        guard case .failed(let message) = phase else { return nil }
        return message
    }

    func pair() {
        let value = pairingPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = value.data(using: .utf8), !data.isEmpty else {
            phase = .failed(text("mac.error.paste_pairing"))
            return
        }

        do {
            let payload = try PairingPayloadParser().parse(data)
            let device = TrustedDevice(
                deviceId: payload.deviceId,
                deviceName: payload.deviceName,
                platform: payload.platform,
                publicKey: payload.publicKey,
                pairingToken: payload.pairingToken,
                pairedAt: Date(),
                lastSeenAt: nil,
                trustStatus: .trusted,
                transportSecurity: payload.transportSecurity
            )
            savePairing(payload: payload, device: device)
        } catch PairingPayloadParserError.expired {
            phase = .failed(text("mac.error.pairing_expired"))
        } catch {
            phase = .failed(text("mac.error.pairing_invalid"))
        }
    }

    func beginMacPairing() {
        selectedNearbyAndroidDeviceID = nil
        startMacPairing(expectedPeerDeviceID: nil)
    }

    func beginMacPairing(with device: NearbyAndroidDevice) {
        selectedNearbyAndroidDeviceID = device.deviceId
        startMacPairing(expectedPeerDeviceID: device.deviceId)
    }

    private func startMacPairing(expectedPeerDeviceID: String?) {
        pairingSetupTask?.cancel()
        pairingListener.stop()
        pairingQRCodePayload = nil
        phase = .connecting
        pairingSetupTask = Task {
            do {
                let offer = try await pairingListener.start(
                    localDeviceId: targetDeviceId,
                    expectedPeerDeviceId: expectedPeerDeviceID
                ) { [weak self] data in
                    Task { @MainActor in self?.acceptAndroidPairing(data) }
                }
                guard !Task.isCancelled else { return }
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.sortedKeys]
                pairingQRCodePayload = String(data: try encoder.encode(offer), encoding: .utf8)
                phase = .ready
            } catch is CancellationError {
                return
            } catch {
                pairingQRCodePayload = nil
                phase = .failed(text("mac.error.pairing_listener"))
            }
            pairingSetupTask = nil
        }
        if nearbyAndroidDevices.isEmpty { refreshNearbyDevices() }
    }

    func stopMacPairing() {
        pairingSetupTask?.cancel()
        pairingSetupTask = nil
        pairingListener.stop()
        nearbyDiscoveryTask?.cancel()
        nearbyDiscoveryTask = nil
        nearbyDiscovery.stop()
        isDiscoveringNearbyDevices = false
        selectedNearbyAndroidDeviceID = nil
        pairingQRCodePayload = nil
        if !isPaired { phase = .ready }
    }

    func refreshNearbyDevices() {
        guard !isDiscoveringNearbyDevices else { return }
        nearbyAndroidDevices = []
        isDiscoveringNearbyDevices = true
        nearbyDiscoveryTask = Task {
            guard !Task.isCancelled else { return }
            let devices = await nearbyDiscovery.discoverPeers(timeout: 3)
            guard !Task.isCancelled else { return }
            nearbyAndroidDevices = devices
            isDiscoveringNearbyDevices = false
            nearbyDiscoveryTask = nil
        }
    }

    func refreshPhotos() {
        guard !isBusy else { return }
        batchProgress = nil
        syncTask = Task { _ = await loadManifest() }
    }

    func syncNextPhoto() {
        guard !isBusy else { return }
        syncTask = Task {
            if manifest == nil, await loadManifest() == false {
                return
            }
            await transferPhotos(limit: 1)
        }
    }

    func syncAllPhotos() {
        guard !isBusy else { return }
        syncTask = Task {
            if manifest == nil, await loadManifest() == false {
                return
            }
            await transferPhotos(limit: Int.max)
        }
    }

    func syncNow() {
        startFreshSync(limit: Int.max)
    }

    func syncNotes() {
        guard isPaired, !isNoteSyncing else { return }
        noteSyncTask?.cancel()
        noteSyncTask = Task { [weak self] in
            guard let self else { return }
            await self.performNoteSync()
            self.noteSyncTask = nil
        }
    }

    @discardableResult
    func saveNote(
        existing: VersionedNote?,
        title: String,
        markdownBody: String,
        tags: [String]
    ) -> Bool {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBody = markdownBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty || !normalizedBody.isEmpty else {
            noteMutationError = text("mac.notes.empty_error")
            return false
        }
        do {
            if let existing {
                _ = try noteRepository.update(
                    id: existing.id,
                    expectedRevision: existing.revision,
                    title: normalizedTitle,
                    markdownBody: markdownBody,
                    tags: tags
                )
            } else {
                _ = try noteRepository.create(
                    title: normalizedTitle,
                    markdownBody: markdownBody,
                    tags: tags
                )
            }
            noteMutationError = nil
            refreshNoteCount()
            return true
        } catch {
            noteMutationError = text("mac.notes.save_error")
            return false
        }
    }

    func deleteNote(_ note: VersionedNote) {
        do {
            _ = try noteRepository.delete(id: note.id, expectedRevision: note.revision)
            noteMutationError = nil
            refreshNoteCount()
        } catch {
            noteMutationError = text("mac.notes.save_error")
        }
    }

    func clearNoteMutationError() {
        noteMutationError = nil
    }

    private func syncScheduledBatch() {
        let limit = scheduledBatchLimit == 0 ? Int.max : scheduledBatchLimit
        startFreshSync(limit: limit)
    }

    private func startFreshSync(limit: Int) {
        guard !isBusy, isPaired else { return }
        batchProgress = nil
        syncTask = Task {
            if await loadManifest() {
                await transferPhotos(limit: limit)
            }
            if automaticNoteSyncEnabled && !Task.isCancelled {
                await performNoteSync()
            }
        }
    }

    private func performNoteSync() async {
        guard isPaired, !isNoteSyncing else { return }
        noteSyncState = .syncing
        do {
            let endpoint = try await resolvedEndpoint()
            guard let signingContext else {
                throw NoteSyncClientError.unacceptableStatusCode(401)
            }
            let result = try await noteSyncClient.synchronize(
                repository: noteRepository,
                host: endpoint.host,
                port: endpoint.port,
                signingContext: RequestSigningContext(
                    deviceId: signingContext.deviceId,
                    sessionId: "mac-notes-v1",
                    secret: signingContext.secret
                ),
                transportSecurity: pairedDevice?.transportSecurity
            )
            guard !Task.isCancelled else { return }
            persist(endpoint: endpoint)
            refreshNoteCount()
            let changed = result.pullMerge.acceptedRemoteCount + result.pullMerge.conflictCount
            noteSyncState = .completed(
                Date(),
                changedCount: changed,
                conflictCount: result.pullMerge.conflictCount
            )
        } catch is CancellationError {
            noteSyncState = .idle
        } catch {
            noteSyncState = .failed(text("mac.notes.error"))
        }
    }

    func cancel() {
        syncTask?.cancel()
        syncTask = nil
        phase = .ready
        progress = nil
        batchProgress = nil
    }

    func forgetDevice() {
        guard !isBusy else { return }
        if let endpointPort = Int(port),
           let secret = pairingToken,
           !host.isEmpty,
           !secret.isEmpty {
            let endpointHost = host
            let transportSecurity = pairedDevice?.transportSecurity
            Task {
                try? await deviceUnregistrationClient.unregister(
                    deviceId: targetDeviceId,
                    sessionId: "mac-photo-mvp",
                    secret: secret,
                    host: endpointHost,
                    port: endpointPort,
                    transportSecurity: transportSecurity
                )
            }
        }
        try? sessionStore.clear()
        pairedDevice = nil
        pairingToken = nil
        manifest = nil
        host = ""
        port = "48291"
        lastSyncedFileName = nil
        batchProgress = nil
        phase = .ready
        noteSyncTask?.cancel()
        noteSyncTask = nil
        noteSyncState = .idle
    }

    private func acceptAndroidPairing(_ data: Data) {
        do {
            let payload = try PairingPayloadParser().parse(data, now: .distantPast)
            let device = TrustedDevice(
                deviceId: payload.deviceId,
                deviceName: payload.deviceName,
                platform: payload.platform,
                publicKey: payload.publicKey,
                pairingToken: payload.pairingToken,
                pairedAt: Date(),
                lastSeenAt: nil,
                trustStatus: .trusted,
                transportSecurity: payload.transportSecurity
            )
            savePairing(payload: payload, device: device)
        } catch {
            phase = .failed(text("mac.error.pairing_invalid"))
        }
    }

    private func savePairing(payload: PairingPayload, device: TrustedDevice) {
        pairedDevice = device
        pairingToken = payload.pairingToken
        host = payload.ip
        port = String(payload.port)
        manifest = nil
        try? sessionStore.save(
            PairedDeviceSession(host: payload.ip, port: payload.port, device: device)
        )
        pairingPayload = ""
        pairingQRCodePayload = nil
        batchProgress = nil
        phase = .ready
        refreshAfterPairing()
    }

    private func refreshAfterPairing() {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.loadManifest()
        }
    }

    func resetLocalHistory() {
        guard !isBusy else { return }
        stateStore.clear()
        try? resultStore.clear()
        try? syncEventStore.clear()
        manifest = nil
        lastSyncedFileName = nil
        batchProgress = nil
        completionReturnState = .none
        recentSyncHistory = []
        phase = .ready
    }

    private func restartScheduledSync() {
        scheduledSyncTask?.cancel()
        scheduledSyncTask = nil
        nextScheduledSyncAt = nil
        guard automaticSyncEnabled else { return }

        scheduledSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = max(self.scheduledSyncIntervalMinutes, 1)
                self.nextScheduledSyncAt = Date().addingTimeInterval(TimeInterval(interval * 60))
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval) * 60 * 1_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                if self.isPaired && !self.isBusy {
                    self.syncScheduledBatch()
                }
            }
        }
    }

    private func loadManifest() async -> Bool {
        guard isPaired else {
            phase = .failed(text("mac.error.pair_first"))
            return false
        }

        phase = .connecting
        do {
            let endpoint = try await resolvedEndpoint()
            let health = try await healthClient.fetchHealth(
                from: endpoint.host,
                port: endpoint.port,
                transportSecurity: pairedDevice?.transportSecurity
            )
            guard health.deviceId == pairedDevice?.deviceId else {
                throw EndpointResolutionError.unexpectedPeer
            }
            persist(endpoint: endpoint)
            phase = .loadingPhotos
            let loaded = try await manifestClient.fetchAllManifestPages(
                from: endpoint.host,
                port: endpoint.port,
                pairingToken: pairingToken,
                signingContext: signingContext,
                transportSecurity: pairedDevice?.transportSecurity
            )
            manifest = loaded
            await reconcileMissingPhotoAssets(in: loaded)
            await publishResult(for: loaded, endpoint: endpoint)
            phase = .ready
            return true
        } catch {
            phase = .failed(Self.message(for: error))
            return false
        }
    }

    private func transferPhotos(limit: Int) async {
        guard let manifest else {
            phase = .failed(text("mac.error.protocol"))
            return
        }
        let assets = planner.nextTransferCandidates(
            in: manifest,
            stateStore: stateStore,
            limit: limit
        )
        guard !assets.isEmpty else {
            phase = .completed
            return
        }

        let permission = await importer.requestPhotoLibraryPermission()
        guard permission.allowsImport else {
            phase = .failed(text("mac.error.photos_permission"))
            return
        }

        do {
            let endpoint = try await resolvedEndpoint()
            var completedCount = 0
            var failedCount = 0
            batchProgress = BatchProgress(
                totalCount: assets.count,
                completedCount: 0,
                failedCount: 0,
                currentFileName: assets.first?.fileName
            )

            for asset in assets {
                guard !Task.isCancelled else { return }
                batchProgress = BatchProgress(
                    totalCount: assets.count,
                    completedCount: completedCount,
                    failedCount: failedCount,
                    currentFileName: asset.fileName
                )
                phase = .downloading

                let importRequest: PhotoImportRequest?
                if let existing = downloadedRequest(for: asset) {
                    importRequest = existing
                } else {
                    let downloads = await downloader.downloadMedia(
                        assets: [asset],
                        host: endpoint.host,
                        port: endpoint.port,
                        stateStore: stateStore,
                        pairingToken: pairingToken,
                        signingContext: signingContext,
                        transportSecurity: pairedDevice?.transportSecurity,
                        progress: { [weak self] value in
                            await MainActor.run { self?.progress = value }
                        }
                    )
                    importRequest = downloads.first.map { download in
                        PhotoImportRequest(
                            sourceAssetId: asset.assetId,
                            sourceHash: asset.sha256,
                            sourceSize: asset.size,
                            localFileURL: download.localFileURL,
                            mediaType: asset.mediaType
                        )
                    }
                }

                guard !Task.isCancelled else { return }
                guard let importRequest else {
                    failedCount += 1
                    progress = nil
                    batchProgress = BatchProgress(
                        totalCount: assets.count,
                        completedCount: completedCount,
                        failedCount: failedCount,
                        currentFileName: nil
                    )
                    await publishResult(for: manifest, endpoint: endpoint)
                    continue
                }

                phase = .importing
                let result = await importer.importBatch([importRequest]).first
                if let result, result.status == .synced {
                    try? FileManager.default.removeItem(at: importRequest.localFileURL)
                    stateStore.markImported(
                        sourceAssetId: result.sourceAssetId,
                        photoLocalIdentifier: result.localIdentifier,
                        now: Date()
                    )
                    lastSyncedFileName = asset.fileName
                    completedCount += 1
                } else {
                    stateStore.markFailed(
                        sourceAssetId: asset.assetId,
                        errorCode: result?.errorCode ?? "SS-MEDIA-999",
                        now: Date()
                    )
                    failedCount += 1
                }
                progress = nil
                batchProgress = BatchProgress(
                    totalCount: assets.count,
                    completedCount: completedCount,
                    failedCount: failedCount,
                    currentFileName: nil
                )
                await publishResult(for: manifest, endpoint: endpoint)
                guard !Task.isCancelled else { return }
            }

            phase = failedCount == 0
                ? .completed
                : .failed(text("mac.error.partial_transfer"))
        } catch {
            progress = nil
            phase = .failed(Self.message(for: error))
        }
    }

    private func publishResult(for manifest: SyncManifest, endpoint: PairedDeviceEndpoint) async {
        let result = SyncResultBuilder().buildMediaResult(
            syncBatchId: "mac-\(manifest.cursor)",
            targetDeviceId: targetDeviceId,
            records: planner.syncResultRecords(in: manifest, stateStore: stateStore)
        )
        try? resultStore.save(result)
        do {
            _ = try await resultClient.postSyncResult(
                result,
                to: endpoint.host,
                port: endpoint.port,
                pairingToken: pairingToken,
                signingContext: signingContext,
                transportSecurity: pairedDevice?.transportSecurity
            )
            recordCompletionReturn(result: result, status: .success)
        } catch {
            recordCompletionReturn(
                result: result,
                status: .failed,
                errorCode: Self.errorCode(for: error)
            )
        }
    }

    private func reconcileMissingPhotoAssets(in manifest: SyncManifest) async {
        let importedAssets = planner.photoAssets(in: manifest).compactMap { asset -> (MediaAsset, String)? in
            guard let record = stateStore.record(for: asset),
                  record.status == .imported,
                  let localIdentifier = record.photoLocalIdentifier,
                  !localIdentifier.isEmpty else { return nil }
            return (asset, localIdentifier)
        }
        guard !importedAssets.isEmpty else { return }

        do {
            let existing = try await importer.existingAssetIdentifiers(
                from: importedAssets.map(\.1)
            )
            let now = Date()
            for (asset, localIdentifier) in importedAssets where !existing.contains(localIdentifier) {
                stateStore.markMissing(sourceAssetId: asset.assetId, now: now)
            }
        } catch {
            return
        }
    }

    private func recordCompletionReturn(
        result: SyncResult,
        status: SyncEventStatus,
        errorCode: String? = nil
    ) {
        let recordedAt = Date()
        let event = SyncEvent.fromResultPost(
            result: result,
            status: status,
            recordedAt: recordedAt,
            errorCode: errorCode
        )
        try? syncEventStore.append(event)
        recentSyncHistory = (try? syncEventStore.recentHistorySummaries(limit: 3)) ?? []
        completionReturnState = status == .success
            ? .delivered(recordedAt)
            : .pendingRetry(recordedAt, errorCode ?? "SS-RESULT-POST")
    }

    private func downloadedRequest(for asset: MediaAsset) -> PhotoImportRequest? {
        guard let record = stateStore.record(for: asset),
              record.status == .downloaded || (
                record.status == .failed && record.downloadedBytes == asset.size
              ),
              let url = record.localFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return PhotoImportRequest(
            sourceAssetId: asset.assetId,
            sourceHash: asset.sha256,
            sourceSize: asset.size,
            localFileURL: url,
            mediaType: asset.mediaType
        )
    }

    private func resolvedEndpoint() async throws -> PairedDeviceEndpoint {
        try await endpointResolver.endpointCandidate(
            pairedDevice: pairedDevice,
            host: host,
            port: port,
            discovery: discovery
        )
    }

    private func persist(endpoint: PairedDeviceEndpoint) {
        guard let device = pairedDevice else { return }
        let refreshed = TrustedDevice(
            deviceId: device.deviceId,
            deviceName: device.deviceName,
            platform: device.platform,
            publicKey: device.publicKey,
            pairingToken: device.pairingToken,
            pairedAt: device.pairedAt,
            lastSeenAt: Date(),
            trustStatus: device.trustStatus,
            transportSecurity: device.transportSecurity
        )
        pairedDevice = refreshed
        host = endpoint.host
        port = String(endpoint.port)
        try? sessionStore.save(
            PairedDeviceSession(lastKnownEndpoint: endpoint, device: refreshed)
        )
    }

    private func restorePairing() {
        guard let session = try? sessionStore.load(),
              session.device.trustStatus == .trusted else { return }
        pairedDevice = session.device
        pairingToken = session.device.pairingToken
        host = session.host
        port = String(session.port)
    }

    private func restoreSyncHistory() {
        recentSyncHistory = (try? syncEventStore.recentHistorySummaries(limit: 3)) ?? []
        guard let event = try? syncEventStore.latest(), event.phase == .resultPost else {
            return
        }
        switch event.status {
        case .success:
            completionReturnState = .delivered(event.recordedAt)
        case .failed, .cancelled:
            completionReturnState = .pendingRetry(
                event.recordedAt,
                event.errorCode ?? "SS-RESULT-POST"
            )
        }
    }

    private var signingContext: RequestSigningContext? {
        guard let pairingToken, !pairingToken.isEmpty else { return nil }
        return RequestSigningContext(
            deviceId: targetDeviceId,
            sessionId: "mac-photo-mvp",
            secret: pairingToken
        )
    }

    private func refreshNoteCount() {
        notes = ((try? noteRepository.allNotes()) ?? []).sorted {
            if $0.updatedAtEpochMillis != $1.updatedAtEpochMillis {
                return $0.updatedAtEpochMillis > $1.updatedAtEpochMillis
            }
            return $0.id < $1.id
        }
        noteCount = notes.count
    }

    private static func makeNoteRepository(deviceID: String) -> NoteRepository {
        do {
            return try NoteRepository(store: FileNoteStore(), deviceID: deviceID)
        } catch {
            preconditionFailure("Mac device identity must be valid: \(error)")
        }
    }

    private func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private static func message(for error: Error) -> String {
        if let endpointError = error as? EndpointResolutionError {
            switch endpointError {
            case .missingHost: return NSLocalizedString("mac.error.missing_host", comment: "")
            case .invalidPort: return NSLocalizedString("mac.error.invalid_port", comment: "")
            case .unexpectedPeer: return NSLocalizedString("mac.error.unexpected_peer", comment: "")
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .networkConnectionLost, .timedOut:
                return NSLocalizedString("mac.error.unreachable", comment: "")
            default:
                return urlError.localizedDescription
            }
        }
        if error is DecodingError {
            return NSLocalizedString("mac.error.protocol", comment: "")
        }
        if let clientError = error as? ManifestClientError {
            switch clientError {
            case .unacceptableStatusCode(409):
                return NSLocalizedString("mac.error.inactive_gateway", comment: "")
            case .unacceptableStatusCode:
                return NSLocalizedString("mac.error.manifest_rejected", comment: "")
            case .invalidBaseURL, .nonHTTPResponse, .paginationLimitExceeded, .invalidPaginationCursor:
                return NSLocalizedString("mac.error.protocol", comment: "")
            }
        }
        return error.localizedDescription
    }

    private static func errorCode(for error: Error) -> String {
        if let clientError = error as? SyncResultClientError,
           case .unacceptableStatusCode(let statusCode) = clientError {
            return "HTTP-\(statusCode)"
        }
        if let urlError = error as? URLError {
            return urlError.code.rawValue.description
        }
        return String(describing: type(of: error))
    }
}
