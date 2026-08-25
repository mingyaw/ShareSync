import Foundation

enum ManifestClientError: Error, Equatable {
    case invalidBaseURL
    case nonHTTPResponse
    case unacceptableStatusCode(Int)
}

protocol ManifestFetchingSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ManifestFetchingSession {}

final class ManifestClient {
    private let session: ManifestFetchingSession
    private let decoder: JSONDecoder

    init(session: ManifestFetchingSession = URLSession.shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func fetchManifest(
        from host: String,
        port: Int,
        cursor: String? = nil,
        pairingToken: String? = nil
    ) async throws -> SyncManifest {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/v1/manifest"
        if let cursor {
            components.queryItems = [URLQueryItem(name: "sinceCursor", value: cursor)]
        }

        guard let url = components.url else {
            throw ManifestClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        if let pairingToken, !pairingToken.isEmpty {
            request.setValue(pairingToken, forHTTPHeaderField: "X-ShareSync-Pairing-Token")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ManifestClientError.nonHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ManifestClientError.unacceptableStatusCode(httpResponse.statusCode)
        }

        return try decoder.decode(SyncManifest.self, from: data)
    }
}
