import Foundation

@MainActor
final class ManifestFetchViewModel: ObservableObject {
    enum FetchState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    struct ManifestSummary: Equatable {
        let sourceDeviceId: String
        let cursor: String
        let photoCount: Int
        let videoCount: Int
        let totalBytes: Int64

        var totalItems: Int {
            photoCount + videoCount
        }
    }

    @Published var host = ""
    @Published var port = "48291"
    @Published private(set) var state: FetchState = .idle
    @Published private(set) var summary: ManifestSummary?

    private let client: ManifestClient

    init(client: ManifestClient = ManifestClient()) {
        self.client = client
    }

    var canFetch: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Int(port) != nil && state != .loading
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
                summary = ManifestSummary(manifest: manifest)
                state = .loaded
            } catch {
                summary = nil
                state = .failed(Self.message(for: error))
            }
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
    init(manifest: SyncManifest) {
        sourceDeviceId = manifest.sourceDeviceId
        cursor = manifest.cursor
        photoCount = manifest.media.filter { $0.mediaType == .photo }.count
        videoCount = manifest.media.filter { $0.mediaType == .video }.count
        totalBytes = manifest.media.reduce(0) { $0 + $1.size }
    }
}
