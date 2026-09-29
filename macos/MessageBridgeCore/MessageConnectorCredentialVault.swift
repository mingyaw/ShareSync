import Foundation

public protocol MessageConnectorCredentialVault: AnyObject {
    func credential(for connectorID: String) throws -> Data?
    func setCredential(_ credential: Data, for connectorID: String) throws
    func removeCredential(for connectorID: String) throws
}

public final class InMemoryMessageConnectorCredentialVault: MessageConnectorCredentialVault {
    private var credentials: [String: Data] = [:]

    public init() {}

    public func credential(for connectorID: String) throws -> Data? {
        credentials[connectorID]
    }

    public func setCredential(_ credential: Data, for connectorID: String) throws {
        credentials[connectorID] = credential
    }

    public func removeCredential(for connectorID: String) throws {
        credentials.removeValue(forKey: connectorID)
    }
}
