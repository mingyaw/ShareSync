import Foundation

enum SyncResultClientError: Error, Equatable {
    case invalidBaseURL
    case nonHTTPResponse
    case unacceptableStatusCode(Int)
}

protocol SyncResultPostingSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: SyncResultPostingSession {}

final class SyncResultClient {
    private let session: SyncResultPostingSession
    private let encoder: JSONEncoder
    private let requestSigner: RequestSigner

    init(
        session: SyncResultPostingSession = LocalNetworkURLSessionFactory.shortRequestSession(),
        requestSigner: RequestSigner = RequestSigner()
    ) {
        self.session = session
        self.encoder = JSONEncoder()
        self.requestSigner = requestSigner
    }

    func postSyncResult(
        _ result: SyncResult,
        to host: String,
        port: Int,
        pairingToken: String? = nil,
        signingContext: RequestSigningContext? = nil
    ) async throws -> Int {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/v1/sync/result"

        guard let url = components.url else {
            throw SyncResultClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let pairingToken, !pairingToken.isEmpty {
            request.setValue(pairingToken, forHTTPHeaderField: "X-ShareSync-Pairing-Token")
        }
        let body = try encoder.encode(result)
        request.httpBody = body
        if let signingContext {
            requestSigner.sign(request: &request, context: signingContext, body: body)
        }

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncResultClientError.nonHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SyncResultClientError.unacceptableStatusCode(httpResponse.statusCode)
        }

        return httpResponse.statusCode
    }
}
