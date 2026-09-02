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
            .navigationTitle("Receive Photos")
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

            Text("Back up Android photos to iCloud through this iPhone.")
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
                        MetricView(title: "Photos", value: "\(summary.photoCount)")
                        MetricView(title: "Done", value: "\(summary.importedCount + summary.downloadedCount)")
                        MetricView(title: "Left", value: "\(summary.remainingCount)")
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
                        Label("Next", systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canDownload)

                    Button {
                        viewModel.downloadSmallMediaBatch()
                    } label: {
                        Label("5 Photos", systemImage: "square.stack.3d.down.right")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.canDownload)
                }

                Button(role: .cancel) {
                    viewModel.cancelDownload()
                } label: {
                    Label("Stop Transfer", systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canCancelDownload)

                Text("Keep ShareSync open while photos sync. If iOS pauses the app, completed items stay recorded and the remaining photos can resume.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var connectionPanel: some View {
        ProductPanel(title: "Connection") {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    isShowingPairingScanner = true
                } label: {
                    Label("Scan Pairing QR", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                TextField("Android IP", text: $viewModel.host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity, minHeight: 48)

                TextField("Port", text: $viewModel.port)
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
                    Label("Use Pairing Payload", systemImage: "link")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var diagnosticsPanel: some View {
        ProductPanel(title: "Diagnostics") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    copySyncResult()
                } label: {
                    Label("Copy Sync Result", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.latestSyncResultJSON == nil)

                Button(role: .destructive) {
                    viewModel.resetLocalSyncState()
                } label: {
                    Label("Reset Local Sync State", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isTransferActive)

                Button(role: .destructive) {
                    viewModel.clearPairing()
                } label: {
                    Label("Clear Pairing", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isTransferActive || !viewModel.canClearPairing)
            }
        }
    }

    private var statusSection: some View {
        ProductPanel(title: "Status") {
            VStack(alignment: .leading, spacing: 12) {
                StatusRow(title: "Pairing", value: pairedStatus)
                StatusRow(title: "Photos Access", value: photosAccessStatus)
                StatusRow(title: "Screen Lock", value: screenLockStatus)
                if let pairedDevice = viewModel.pairedDevice {
                    StatusRow(title: "Device", value: pairedDevice.deviceName)
                }
                if let health = viewModel.localPeerHealth {
                    StatusRow(title: "Android Peer", value: androidPeerText(health))
                }
                StatusRow(title: "Manifest", value: manifestStatus)

                if let summary = viewModel.summary {
                    StatusRow(title: "Photos", value: "\(summary.photoCount)")
                    StatusRow(title: "Transfer", value: summary.transferStatus)
                    StatusRow(title: "Transfer Size", value: ByteCountFormatter.string(fromByteCount: summary.totalBytes, countStyle: .file))
                    StatusRow(title: "Test Item", value: summary.validationAssetName ?? "None")
                    StatusRow(title: "Downloaded", value: "\(summary.downloadedCount)")
                    StatusRow(title: "Imported", value: "\(summary.importedCount)")
                    StatusRow(title: "Missing", value: "\(summary.missingCount)")
                    StatusRow(title: "Failed", value: "\(summary.failedCount)")
                    StatusRow(title: "Partial", value: "\(summary.partialCount)")
                    if let lastFailureCode = summary.lastFailureCode {
                        StatusRow(title: "Last Failure", value: lastFailureText(code: lastFailureCode, fileName: summary.lastFailureFileName))
                    }
                    StatusRow(title: "Remaining", value: "\(summary.remainingCount)")
                    StatusRow(title: "Cursor", value: summary.cursor)
                } else {
                    StatusRow(title: "Photos", value: "Waiting")
                }

                if let progress = viewModel.downloadProgressSummary {
                    StatusRow(title: "Batch Progress", value: progress.progressText)
                    StatusRow(title: "Batch Downloaded", value: "\(progress.downloadedCount)")
                    StatusRow(title: "Batch Failed", value: "\(progress.failedCount)")
                    if let currentFileName = progress.currentFileName {
                        StatusRow(title: "Current File", value: currentFileName)
                    }
                }

                if let syncResultSummary = viewModel.syncResultSummary {
                    StatusRow(title: "Sync Batch", value: syncResultSummary.syncBatchId)
                    StatusRow(title: "Synced", value: "\(syncResultSummary.syncedCount)")
                    StatusRow(title: "Skipped", value: "\(syncResultSummary.skippedCount)")
                    StatusRow(title: "Result Failed", value: "\(syncResultSummary.failedCount)")
                }
                if let returnSummary = viewModel.syncResultReturnSummary {
                    StatusRow(title: "Result Return", value: syncResultReturnText(returnSummary))
                }

                if viewModel.latestSyncResultJSON != nil, let syncResultCopyMessage {
                    Text(syncResultCopyMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                if case .cancelled = viewModel.downloadState {
                    Text(viewModel.cancellationMessage ?? "Transfer stopped. Completed items are kept; remaining items can be retried.")
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
            return "Fetching"
        default:
            return "Fetch Manifest"
        }
    }

    private var downloadButtonTitle: String {
        switch viewModel.downloadState {
        case .downloading:
            return "Downloading"
        case .importing:
            return "Importing"
        case .cancelled:
            return "Download Next Item"
        case .completed:
            return "Download Next Item"
        default:
            return "Download Next Item"
        }
    }

    private var batchDownloadButtonTitle: String {
        switch viewModel.downloadState {
        case .downloading:
            return "Downloading"
        case .importing:
            return "Importing"
        case .cancelled:
            return "Download 5 Items"
        default:
            return "Download 5 Items"
        }
    }

    private var remainingDownloadButtonTitle: String {
        switch viewModel.downloadState {
        case .downloading:
            return "Syncing Photos"
        case .importing:
            return "Importing Photos"
        case .cancelled:
            return "Resume Photo Sync"
        default:
            return "Sync All Photos"
        }
    }

    private var summarySubtitle: String {
        if let summary = viewModel.summary {
            switch summary.transferStatus {
            case "Complete":
                return "All manifest photos are backed up or skipped."
            case "Needs Retry":
                return "Some photos need attention before this sync is complete."
            case "No Photos":
                return "Android has no photos to send right now."
            default:
                return "\(summary.remainingCount) photos ready to sync."
            }
        }

        if viewModel.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Pair with your Android phone to begin."
        }

        return "Fetch the latest Android photo list."
    }

    private var summaryIconName: String {
        switch phaseStatus {
        case "Transfer Complete":
            return "checkmark.circle.fill"
        case "Retry Required", "Transfer Error", "Fetch Error":
            return "exclamationmark.triangle.fill"
        case "Transfer Active", "Fetching Manifest":
            return "arrow.triangle.2.circlepath"
        default:
            return "photo.on.rectangle.angled"
        }
    }

    private var summaryTint: Color {
        switch phaseStatus {
        case "Transfer Complete":
            return .green
        case "Retry Required", "Transfer Error", "Fetch Error":
            return .orange
        case "Transfer Active", "Fetching Manifest":
            return .blue
        default:
            return .secondary
        }
    }

    private var pairedStatus: String {
        viewModel.host.isEmpty ? "Manual" : "\(viewModel.host):\(viewModel.port)"
    }

    private var phaseStatus: String {
        if viewModel.isTransferActive {
            return "Transfer Active"
        }

        if case .loading = viewModel.state {
            return "Fetching Manifest"
        }

        if case .failed = viewModel.state {
            return "Fetch Error"
        }

        if case .failed = viewModel.downloadState {
            return "Transfer Error"
        }

        if case .cancelled = viewModel.downloadState {
            return "Retry Required"
        }

        if viewModel.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Pairing Required"
        }

        guard let summary = viewModel.summary else {
            return "Ready To Fetch"
        }

        switch summary.transferStatus {
        case "Complete":
            return "Transfer Complete"
        case "Needs Retry":
            return "Retry Required"
        case "No Photos":
            return "No Photos"
        default:
            return "Ready To Transfer"
        }
    }

    private var manifestStatus: String {
        switch viewModel.state {
        case .idle:
            return "Ready"
        case .loading:
            return "Loading"
        case .loaded:
            return "\(viewModel.summary?.photoCount ?? 0) photos"
        case .failed:
            return "Failed"
        }
    }

    private var photosAccessStatus: String {
        switch viewModel.photoLibraryPermissionStatus {
        case .authorized:
            return "Allowed"
        case .limited:
            return "Limited"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Asked"
        case .unknown:
            return "Unknown"
        }
    }

    private var screenLockStatus: String {
        shouldKeepScreenAwake(for: viewModel.downloadState) ? "Paused" : "Normal"
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
        "Ready - \(health.deviceId) - v\(health.protocolVersion)"
    }

    private func copySyncResult() {
        guard let json = viewModel.latestSyncResultJSON else {
            return
        }

        UIPasteboard.general.string = json
        syncResultCopyMessage = "Sync result JSON copied."
    }

    private func updateIdleTimer(for state: ManifestFetchViewModel.DownloadState) {
        UIApplication.shared.isIdleTimerDisabled = shouldKeepScreenAwake(for: state)
    }

    private func shouldKeepScreenAwake(for state: ManifestFetchViewModel.DownloadState) -> Bool {
        state == .downloading || state == .importing
    }
}

private struct StatusRow: View {
    let title: String
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
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
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
    let title: String
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
