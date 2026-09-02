import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ManifestFetchViewModel()
    @State private var isShowingPairingScanner = false
    @State private var syncResultCopyMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    transferSummaryPanel
                    primaryActions
                    connectionPanel
                    statusSection
                    diagnosticsPanel
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("ios.nav.receive_photos")
            .fullScreenCover(isPresented: $isShowingPairingScanner) {
                QRCodeScannerView { payload in
                    viewModel.pairingPayloadText = payload
                    viewModel.applyPairingPayload()
                }
            }
            .onChange(of: viewModel.downloadState) { _, newState in
                updateIdleTimer(for: newState)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    viewModel.cancelDownloadForBackground()
                }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ShareSync")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("ios.header.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transferSummaryPanel: some View {
        ProductPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phaseStatus)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(summarySubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Image(systemName: summaryIconName)
                        .font(.title2)
                        .foregroundStyle(summaryTint)
                }

                if let summary = viewModel.summary {
                    HStack(spacing: 10) {
                        MetricView(title: "ios.metric.photos", value: "\(summary.photoCount)")
                        MetricView(title: "ios.metric.done", value: "\(summary.importedCount + summary.downloadedCount)")
                        MetricView(title: "ios.metric.left", value: "\(summary.remainingCount)")
                    }
                }
            }
        }
    }

    private var primaryActions: some View {
        ProductPanel {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    viewModel.fetchManifest()
                } label: {
                    Label(buttonTitle, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canFetch)

                Button {
                    viewModel.downloadRemainingMedia()
                } label: {
                    HStack {
                        if viewModel.isTransferActive {
                            ProgressView()
                        }
                        Label(remainingDownloadButtonTitle, systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .frame(minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canDownload)

                HStack(spacing: 12) {
                    Button {
                        viewModel.downloadFirstMedia()
                    } label: {
                        Label("ios.action.next", systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canDownload)

                    Button {
                        viewModel.downloadSmallMediaBatch()
                    } label: {
                        Label("ios.action.five_photos", systemImage: "square.stack.3d.down.right")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canDownload)
                }

                Button(role: .cancel) {
                    viewModel.cancelDownload()
                } label: {
                    Label("ios.action.stop_transfer", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canCancelDownload)

                Text("ios.footer.foreground")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var connectionPanel: some View {
        ProductPanel(title: "ios.panel.connection") {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    isShowingPairingScanner = true
                } label: {
                    Label("ios.action.scan_pairing_qr", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                TextField("ios.connection.android_ip", text: $viewModel.host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity, minHeight: 48)

                TextField("ios.connection.port", text: $viewModel.port)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity, minHeight: 48)

                TextEditor(text: $viewModel.pairingPayloadText)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    }

                Button {
                    viewModel.applyPairingPayload()
                } label: {
                    Label("ios.action.use_pairing_payload", systemImage: "link")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var diagnosticsPanel: some View {
        ProductPanel(title: "ios.panel.diagnostics") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    copySyncResult()
                } label: {
                    Label("ios.action.copy_sync_result", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.latestSyncResultJSON == nil)

                Button(role: .destructive) {
                    viewModel.resetLocalSyncState()
                } label: {
                    Label("ios.action.reset_local_sync_state", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isTransferActive)

                Button(role: .destructive) {
                    viewModel.clearPairing()
                } label: {
                    Label("ios.action.clear_pairing", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isTransferActive || !viewModel.canClearPairing)
            }
        }
    }

    private var statusSection: some View {
        ProductPanel(title: "ios.panel.status") {
            VStack(alignment: .leading, spacing: 12) {
                StatusRow(title: "ios.status.pairing", value: pairedStatus)
                StatusRow(title: "ios.status.photos_access", value: photosAccessStatus)
                StatusRow(title: "ios.status.screen_lock", value: screenLockStatus)
                if let pairedDevice = viewModel.pairedDevice {
                    StatusRow(title: "ios.status.device", value: pairedDevice.deviceName)
                }
                if let health = viewModel.localPeerHealth {
                    StatusRow(title: "ios.status.android_peer", value: androidPeerText(health))
                }
                StatusRow(title: "ios.status.manifest", value: manifestStatus)

                if let summary = viewModel.summary {
                    StatusRow(title: "ios.status.photos", value: "\(summary.photoCount)")
                    StatusRow(title: "ios.status.transfer", value: localizedTransferStatus(summary.transferStatus))
                    StatusRow(title: "ios.status.transfer_size", value: ByteCountFormatter.string(fromByteCount: summary.totalBytes, countStyle: .file))
                    StatusRow(title: "ios.status.test_item", value: summary.validationAssetName ?? localized("ios.value.none"))
                    StatusRow(title: "ios.status.downloaded", value: "\(summary.downloadedCount)")
                    StatusRow(title: "ios.status.imported", value: "\(summary.importedCount)")
                    StatusRow(title: "ios.status.missing", value: "\(summary.missingCount)")
                    StatusRow(title: "ios.status.failed", value: "\(summary.failedCount)")
                    StatusRow(title: "ios.status.partial", value: "\(summary.partialCount)")
                    if let lastFailureCode = summary.lastFailureCode {
                        StatusRow(title: "ios.status.last_failure", value: lastFailureText(code: lastFailureCode, fileName: summary.lastFailureFileName))
                    }
                    StatusRow(title: "ios.status.remaining", value: "\(summary.remainingCount)")
                    StatusRow(title: "ios.status.cursor", value: summary.cursor)
                } else {
                    StatusRow(title: "ios.status.photos", value: localized("ios.status.waiting"))
                }

                if let progress = viewModel.downloadProgressSummary {
                    StatusRow(title: "ios.status.batch_progress", value: progress.progressText)
                    StatusRow(title: "ios.status.batch_downloaded", value: "\(progress.downloadedCount)")
                    StatusRow(title: "ios.status.batch_failed", value: "\(progress.failedCount)")
                    if let currentFileName = progress.currentFileName {
                        StatusRow(title: "ios.status.current_file", value: currentFileName)
                    }
                }

                if let syncResultSummary = viewModel.syncResultSummary {
                    StatusRow(title: "ios.status.sync_batch", value: syncResultSummary.syncBatchId)
                    StatusRow(title: "ios.status.synced", value: "\(syncResultSummary.syncedCount)")
                    StatusRow(title: "ios.status.skipped", value: "\(syncResultSummary.skippedCount)")
                    StatusRow(title: "ios.status.result_failed", value: "\(syncResultSummary.failedCount)")
                }
                if let returnSummary = viewModel.syncResultReturnSummary {
                    StatusRow(title: "ios.status.result_return", value: syncResultReturnText(returnSummary))
                }

                if viewModel.latestSyncResultJSON != nil, let syncResultCopyMessage {
                    Text(syncResultCopyMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                if case .cancelled = viewModel.downloadState {
                    Text(viewModel.cancellationMessage ?? localized("ios.transfer.cancelled_default"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                if case .failed(let message) = viewModel.state {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                if case .failed(let message) = viewModel.downloadState {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var buttonTitle: String {
        switch viewModel.state {
        case .loading:
            return localized("ios.action.fetching")
        default:
            return localized("ios.action.fetch_manifest")
        }
    }

    private var remainingDownloadButtonTitle: String {
        switch viewModel.downloadState {
        case .downloading:
            return localized("ios.action.syncing_photos")
        case .importing:
            return localized("ios.action.importing_photos")
        case .cancelled:
            return localized("ios.action.resume_photo_sync")
        default:
            return localized("ios.action.sync_all_photos")
        }
    }

    private var summarySubtitle: String {
        if let summary = viewModel.summary {
            switch summary.transferStatus {
            case "Complete":
                return localized("ios.summary.all_complete")
            case "Needs Retry":
                return localized("ios.summary.retry_required")
            case "No Photos":
                return localized("ios.summary.no_photos")
            default:
                return String(format: localized("ios.summary.remaining_format"), summary.remainingCount)
            }
        }

        if viewModel.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localized("ios.summary.pair_to_begin")
        }

        return localized("ios.summary.fetch_latest")
    }

    private var summaryIconName: String {
        switch phaseKind {
        case .transferComplete:
            return "checkmark.circle.fill"
        case .retryRequired, .transferError, .fetchError:
            return "exclamationmark.triangle.fill"
        case .transferActive, .fetchingManifest:
            return "arrow.triangle.2.circlepath"
        default:
            return "photo.on.rectangle.angled"
        }
    }

    private var summaryTint: Color {
        switch phaseKind {
        case .transferComplete:
            return .green
        case .retryRequired, .transferError, .fetchError:
            return .orange
        case .transferActive, .fetchingManifest:
            return .blue
        default:
            return .secondary
        }
    }

    private var pairedStatus: String {
        viewModel.host.isEmpty ? localized("ios.status.manual") : "\(viewModel.host):\(viewModel.port)"
    }

    private var phaseStatus: String {
        switch phaseKind {
        case .transferActive:
            return localized("ios.phase.transfer_active")
        case .fetchingManifest:
            return localized("ios.phase.fetching_manifest")
        case .fetchError:
            return localized("ios.phase.fetch_error")
        case .transferError:
            return localized("ios.phase.transfer_error")
        case .retryRequired:
            return localized("ios.phase.retry_required")
        case .pairingRequired:
            return localized("ios.phase.pairing_required")
        case .readyToFetch:
            return localized("ios.phase.ready_to_fetch")
        case .transferComplete:
            return localized("ios.phase.transfer_complete")
        case .noPhotos:
            return localized("ios.phase.no_photos")
        case .readyToTransfer:
            return localized("ios.phase.ready_to_transfer")
        }
    }

    private var phaseKind: PhaseKind {
        if viewModel.isTransferActive {
            return .transferActive
        }

        if case .loading = viewModel.state {
            return .fetchingManifest
        }

        if case .failed = viewModel.state {
            return .fetchError
        }

        if case .failed = viewModel.downloadState {
            return .transferError
        }

        if case .cancelled = viewModel.downloadState {
            return .retryRequired
        }

        if viewModel.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .pairingRequired
        }

        guard let summary = viewModel.summary else {
            return .readyToFetch
        }

        switch summary.transferStatus {
        case "Complete":
            return .transferComplete
        case "Needs Retry":
            return .retryRequired
        case "No Photos":
            return .noPhotos
        default:
            return .readyToTransfer
        }
    }

    private var manifestStatus: String {
        switch viewModel.state {
        case .idle:
            return localized("ios.status.ready")
        case .loading:
            return localized("ios.status.loading")
        case .loaded:
            return String(format: localized("ios.value.photo_count_format"), viewModel.summary?.photoCount ?? 0)
        case .failed:
            return localized("ios.status.failed")
        }
    }

    private var photosAccessStatus: String {
        switch viewModel.photoLibraryPermissionStatus {
        case .authorized:
            return localized("ios.status.allowed")
        case .limited:
            return localized("ios.status.limited")
        case .denied:
            return localized("ios.status.denied")
        case .restricted:
            return localized("ios.status.restricted")
        case .notDetermined:
            return localized("ios.status.not_asked")
        case .unknown:
            return localized("ios.status.unknown")
        }
    }

    private var screenLockStatus: String {
        shouldKeepScreenAwake(for: viewModel.downloadState) ? localized("ios.status.paused") : localized("ios.status.normal")
    }

    private func lastFailureText(code: String, fileName: String?) -> String {
        guard let fileName, !fileName.isEmpty else {
            return code
        }
        return "\(code) - \(fileName)"
    }

    private func syncResultReturnText(_ summary: ManifestFetchViewModel.SyncResultReturnSummary) -> String {
        if let httpStatusCode = summary.httpStatusCode {
            return "\(summary.status) HTTP \(httpStatusCode)"
        }

        return summary.status
    }

    private func androidPeerText(_ health: LocalPeerHealth) -> String {
        String(format: localized("ios.value.ready_device_format"), health.deviceId, health.protocolVersion)
    }

    private func copySyncResult() {
        guard let json = viewModel.latestSyncResultJSON else {
            return
        }

        UIPasteboard.general.string = json
        syncResultCopyMessage = localized("ios.toast.sync_result_copied")
    }

    private func updateIdleTimer(for state: ManifestFetchViewModel.DownloadState) {
        UIApplication.shared.isIdleTimerDisabled = shouldKeepScreenAwake(for: state)
    }

    private func shouldKeepScreenAwake(for state: ManifestFetchViewModel.DownloadState) -> Bool {
        state == .downloading || state == .importing
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func localizedTransferStatus(_ status: String) -> String {
        switch status {
        case "Complete":
            return localized("ios.phase.transfer_complete")
        case "Needs Retry":
            return localized("ios.phase.retry_required")
        case "No Photos":
            return localized("ios.phase.no_photos")
        default:
            return localized("ios.status.ready")
        }
    }
}

private enum PhaseKind {
    case fetchError
    case fetchingManifest
    case noPhotos
    case pairingRequired
    case readyToFetch
    case readyToTransfer
    case retryRequired
    case transferActive
    case transferComplete
    case transferError
}

private struct StatusRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(.medium)
                .lineLimit(1)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
    }
}

private struct ProductPanel<Content: View>: View {
    let title: LocalizedStringKey?
    let content: Content

    init(title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MetricView: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    ContentView()
}
