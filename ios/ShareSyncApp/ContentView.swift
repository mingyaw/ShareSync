import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = ManifestFetchViewModel()
    @State private var isShowingPairingScanner = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ShareSync")
                                .font(.largeTitle)
                                .fontWeight(.semibold)

                            Text("Receive Android photos over your local network.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 20)

                        endpointForm

                        statusSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .frame(width: max(0, geometry.size.width - 32), alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Receive")
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

    private var endpointForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Android IP", text: $viewModel.host)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 48)

            TextField("Port", text: $viewModel.port)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 48)

            TextEditor(text: $viewModel.pairingPayloadText)
                .font(.footnote)
                .frame(maxWidth: .infinity, minHeight: 96)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                }

            Button {
                isShowingPairingScanner = true
            } label: {
                Text("Scan Pairing QR")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button {
                viewModel.applyPairingPayload()
            } label: {
                Text("Apply Pairing Payload")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button {
                viewModel.fetchManifest()
            } label: {
                HStack {
                    if case .loading = viewModel.state {
                        ProgressView()
                    }
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!viewModel.canFetch)

            Button {
                viewModel.downloadFirstMedia()
            } label: {
                HStack {
                    if case .downloading = viewModel.downloadState {
                        ProgressView()
                    }
                    if case .importing = viewModel.downloadState {
                        ProgressView()
                    }
                    Text(downloadButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!viewModel.canDownload)

            Button {
                viewModel.downloadSmallMediaBatch()
            } label: {
                HStack {
                    if case .downloading = viewModel.downloadState {
                        ProgressView()
                    }
                    if case .importing = viewModel.downloadState {
                        ProgressView()
                    }
                    Text(batchDownloadButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!viewModel.canDownload)

            Button {
                viewModel.downloadRemainingMedia()
            } label: {
                HStack {
                    if case .downloading = viewModel.downloadState {
                        ProgressView()
                    }
                    if case .importing = viewModel.downloadState {
                        ProgressView()
                    }
                    Text(remainingDownloadButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!viewModel.canDownload)

            Button(role: .cancel) {
                viewModel.cancelDownload()
            } label: {
                Text("Stop Transfer")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!viewModel.canCancelDownload)

            Button(role: .destructive) {
                viewModel.resetLocalSyncState()
            } label: {
                Text("Reset Local Sync State")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.isTransferActive)

            Button(role: .destructive) {
                viewModel.clearPairing()
            } label: {
                Text("Clear Pairing")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.isTransferActive || !viewModel.canClearPairing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 24)
    }

    private var statusSection: some View {
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
            return "Downloading"
        case .importing:
            return "Importing"
        case .cancelled:
            return "Download Remaining"
        default:
            return "Download Remaining"
        }
    }

    private var pairedStatus: String {
        viewModel.host.isEmpty ? "Manual" : "\(viewModel.host):\(viewModel.port)"
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

    private func androidPeerText(_ health: LocalPeerHealth) -> String {
        "Ready - \(health.deviceId) - v\(health.protocolVersion)"
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

#Preview {
    ContentView()
}
