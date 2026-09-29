import Foundation

public enum MessageConnectorEndpointRejection: Error, Equatable, Sendable {
    case malformedURL
    case insecureScheme
    case credentialsInURL
    case fragmentNotAllowed
    case hostNotAllowed
    case portNotAllowed
}

public struct MessageConnectorEndpointPolicy: Equatable, Sendable {
    public let allowedHosts: Set<String>
    public let allowedPorts: Set<Int>

    public init(allowedHosts: Set<String>, allowedPorts: Set<Int> = [443]) {
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
        self.allowedPorts = allowedPorts
    }

    public func validate(_ url: URL) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            throw MessageConnectorEndpointRejection.malformedURL
        }
        guard scheme == "https" else {
            throw MessageConnectorEndpointRejection.insecureScheme
        }
        guard components.user == nil, components.password == nil else {
            throw MessageConnectorEndpointRejection.credentialsInURL
        }
        guard components.fragment == nil else {
            throw MessageConnectorEndpointRejection.fragmentNotAllowed
        }
        guard allowedHosts.contains(host) else {
            throw MessageConnectorEndpointRejection.hostNotAllowed
        }
        let effectivePort = components.port ?? 443
        guard allowedPorts.contains(effectivePort) else {
            throw MessageConnectorEndpointRejection.portNotAllowed
        }
    }

    public func validateRedirect(from originalURL: URL, to redirectURL: URL) throws {
        try validate(originalURL)
        try validate(redirectURL)
    }
}
