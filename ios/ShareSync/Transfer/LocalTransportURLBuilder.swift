import Foundation

struct LocalTransportURLBuilder {
    static func url(
        host: String,
        port: Int,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        transportSecurity: PairingTransportSecurity? = nil
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme(for: transportSecurity)
        components.host = host
        components.port = port
        components.path = path
        components.queryItems = queryItems
        return components.url
    }

    static func scheme(for transportSecurity: PairingTransportSecurity?) -> String {
        guard transportSecurity?.mode == .qrPinnedHTTPS else {
            return "http"
        }
        return "https"
    }
}
