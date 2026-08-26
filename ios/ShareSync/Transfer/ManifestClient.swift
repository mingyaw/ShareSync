import Foundation

enum ManifestClientError: Error, Equatable {
    case invalidBaseURL
    case nonHTTPResponse
    case unacceptableStatusCode(Int)
}

enum HealthClientError: Error, Equatable {
    case invalidBaseURL
    case nonHTTPResponse
    case unacceptableStatusCode(Int)
    case peerNotReady(String)
}

struct LocalPeerHealth: Decodable, Equatable {
    let status: String
    let deviceId: String
    let appVersion: String
    let protocolVersion: Int

    var isReady: Bool {
        status == "ok"
    }
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

final class HealthClient {
    private let session: ManifestFetchingSession
    private let decoder: JSONDecoder

    init(session: ManifestFetchingSession = URLSession.shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func fetchHealth(from host: String, port: Int) async throws -> LocalPeerHealth {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/v1/health"

        guard let url = components.url else {
            throw HealthClientError.invalidBaseURL
        }

        let (data, response) = try await session.data(for: URLRequest(url: url))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HealthClientError.nonHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HealthClientError.unacceptableStatusCode(httpResponse.statusCode)
        }

        let health = try decoder.decode(LocalPeerHealth.self, from: data)
        guard health.isReady else {
            throw HealthClientError.peerNotReady(health.status)
        }

        return health
    }
}
