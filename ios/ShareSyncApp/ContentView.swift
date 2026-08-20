import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ManifestFetchViewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ShareSync")
                                .font(.largeTitle)
                                .fontWeight(.semibold)

                            Text("Receive Android media over your local network.")
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 24)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusRow(title: "Pairing", value: pairedStatus)
            StatusRow(title: "Manifest", value: manifestStatus)

            if let summary = viewModel.summary {
                StatusRow(title: "Photos", value: "\(summary.photoCount)")
                StatusRow(title: "Videos", value: "\(summary.videoCount)")
                StatusRow(title: "Transfer Size", value: ByteCountFormatter.string(fromByteCount: summary.totalBytes, countStyle: .file))
                StatusRow(title: "Test Item", value: summary.validationAssetName ?? "None")
                StatusRow(title: "Downloaded", value: "\(summary.downloadedCount)")
                StatusRow(title: "Imported", value: "\(summary.importedCount)")
                StatusRow(title: "Failed", value: "\(summary.failedCount)")
                StatusRow(title: "Cursor", value: summary.cursor)
            } else {
                StatusRow(title: "Photos", value: "Waiting")
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
        case .completed:
            return "Download Next Item"
        default:
            return "Download Next Item"
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
            return "\(viewModel.summary?.totalItems ?? 0) items"
        case .failed:
            return "Failed"
        }
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
