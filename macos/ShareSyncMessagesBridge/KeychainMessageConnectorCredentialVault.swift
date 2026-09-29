import Foundation
import Security

final class KeychainMessageConnectorCredentialVault: MessageConnectorCredentialVault {
    private let service: String

    init(service: String = "com.sharesync.messages-bridge.connectors") {
        self.service = service
    }

    func credential(for connectorID: String) throws -> Data? {
        var query = baseQuery(connectorID: connectorID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainCredentialVaultError.operationFailed(status)
        }
        return data
    }

    func setCredential(_ credential: Data, for connectorID: String) throws {
        let query = baseQuery(connectorID: connectorID)
        let attributes = [kSecValueData as String: credential]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainCredentialVaultError.operationFailed(updateStatus)
        }

        var item = query
        item[kSecValueData as String] = credential
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainCredentialVaultError.operationFailed(addStatus)
        }
    }

    func removeCredential(for connectorID: String) throws {
        let status = SecItemDelete(baseQuery(connectorID: connectorID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainCredentialVaultError.operationFailed(status)
        }
    }

    private func baseQuery(connectorID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: connectorID,
        ]
    }
}

enum KeychainCredentialVaultError: Error, Equatable {
    case operationFailed(OSStatus)
}
