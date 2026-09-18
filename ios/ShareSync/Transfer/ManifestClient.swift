import Foundation

enum ManifestClientError: Error, Equatable {
    case invalidBaseURL
    case nonHTTPResponse
    case unacceptableStatusCode(Int)
    case paginationLimitExceeded
    case invalidPaginationCursor
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
    private let session: ManifestFetchingSession?
    private let decoder: JSONDecoder
    private let requestSigner: RequestSigner

    init(
        session: ManifestFetchingSession? = nil,
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
        sinceCursor: String? = nil,
        pageCursor: String? = nil,
        pairingToken: String? = nil,
        signingContext: RequestSigningContext? = nil,
        transportSecurity: PairingTransportSecurity? = nil
    ) async throws -> SyncManifest {
        let queryItems = [
            sinceCursor.map { URLQueryItem(name: "sinceCursor", value: $0) },
            pageCursor.map { URLQueryItem(name: "pageCursor", value: $0) },
        ].compactMap { $0 }
        guard let url = LocalTransportURLBuilder.url(
            host: host,
            port: port,
            path: "/v1/manifest",
            queryItems: queryItems.isEmpty ? nil : queryItems,
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

        let activeSession = session ?? LocalNetworkURLSessionFactory.shortRequestSession(
            transportSecurity: transportSecurity
        )
        let (data, response) = try await activeSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ManifestClientError.nonHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ManifestClientError.unacceptableStatusCode(httpResponse.statusCode)
        }

        return try decoder.decode(SyncManifest.self, from: data)
    }

    func fetchAllManifestPages(
        from host: String,
        port: Int,
        sinceCursor: String? = nil,
        pairingToken: String? = nil,
        signingContext: RequestSigningContext? = nil,
        transportSecurity: PairingTransportSecurity? = nil,
        maximumPages: Int = 50
    ) async throws -> SyncManifest {
        var pageCursor: String?
        var firstPage: SyncManifest?
        var media: [MediaAsset] = []
        var seenAssetIds: Set<String> = []

        let pageLimit = max(1, maximumPages)
        for pageIndex in 0..<pageLimit {
            let page = try await fetchManifest(
                from: host,
                port: port,
                sinceCursor: sinceCursor,
                pageCursor: pageCursor,
                pairingToken: pairingToken,
                signingContext: signingContext,
                transportSecurity: transportSecurity
            )
            if firstPage == nil {
                firstPage = page
            }
            page.media.forEach { asset in
                if seenAssetIds.insert(asset.assetId).inserted {
                    media.append(asset)
                }
            }

            guard page.hasMore == true else {
                break
            }
            guard pageIndex + 1 < pageLimit else {
                throw ManifestClientError.paginationLimitExceeded
            }
            guard let nextCursor = page.nextCursor,
                  !nextCursor.isEmpty,
                  nextCursor != pageCursor else {
                throw ManifestClientError.invalidPaginationCursor
            }
            pageCursor = nextCursor
        }

        guard let firstPage else {
            throw ManifestClientError.nonHTTPResponse
        }
        return SyncManifest(
            version: firstPage.version,
            sourceDeviceId: firstPage.sourceDeviceId,
            generatedAt: firstPage.generatedAt,
            cursor: firstPage.cursor,
            media: media,
            contacts: firstPage.contacts,
            files: firstPage.files,
            pageSize: media.count,
            hasMore: false,
            nextCursor: nil
        )
    }
}

final class HealthClient {
    private let session: ManifestFetchingSession?
    private let decoder: JSONDecoder

    init(session: ManifestFetchingSession? = nil) {
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

        let activeSession = session ?? LocalNetworkURLSessionFactory.shortRequestSession(
            transportSecurity: transportSecurity
        )
        let (data, response) = try await activeSession.data(for: URLRequest(url: url))
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
