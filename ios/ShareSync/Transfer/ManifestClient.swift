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
    private let requestSigner: RequestSigner

    init(
        session: ManifestFetchingSession = LocalNetworkURLSessionFactory.shortRequestSession(),
        requestSigner: RequestSigner = RequestSigner()
    ) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.requestSigner = requestSigner
    }

    func fetchManifest(
        from host: String,
        port: Int,
        cursor: String? = nil,
        pairingToken: String? = nil,
        signingContext: RequestSigningContext? = nil,
        transportSecurity: PairingTransportSecurity? = nil
    ) async throws -> SyncManifest {
        guard let url = LocalTransportURLBuilder.url(
            host: host,
            port: port,
            path: "/v1/manifest",
            queryItems: cursor.map { [URLQueryItem(name: "sinceCursor", value: $0)] },
            transportSecurity: transportSecurity
        ) else {
            throw ManifestClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        if let pairingToken, !pairingToken.isEmpty {
            request.setValue(pairingToken, forHTTPHeaderField: "X-ShareSync-Pairing-Token")
        }
        if let signingContext {
            requestSigner.sign(request: &request, context: signingContext)
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

    init(session: ManifestFetchingSession = LocalNetworkURLSessionFactory.shortRequestSession()) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func fetchHealth(
        from host: String,
        port: Int,
        transportSecurity: PairingTransportSecurity? = nil
    ) async throws -> LocalPeerHealth {
        guard let url = LocalTransportURLBuilder.url(
            host: host,
            port: port,
            path: "/v1/health",
            transportSecurity: transportSecurity
        ) else {
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
