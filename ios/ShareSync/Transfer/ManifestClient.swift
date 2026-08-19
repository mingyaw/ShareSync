import Foundation

enum ManifestClientError: Error {
    case invalidBaseURL
}

final class ManifestClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func fetchManifest(from host: String, port: Int, cursor: String? = nil) async throws -> SyncManifest {
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

        let (data, _) = try await session.data(from: url)
        return try decoder.decode(SyncManifest.self, from: data)
    }
}

