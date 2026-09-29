import Foundation
import SQLite3

public enum MessageDatabaseAccessStatus: Equatable, Sendable {
    case available(schemaFingerprint: String)
    case unavailable
    case permissionRequired
    case unsupportedSchema(schemaFingerprint: String, missing: [String])
    case failed(sqliteCode: Int32)
}

public struct MessageDatabaseAccessProbe {
    public init() {}

    public func status(databaseURL: URL) -> MessageDatabaseAccessStatus {
        do {
            let schema = try MessageDatabaseSchemaInspector().inspect(databaseURL: databaseURL)
            let missing = schema.missingIncrementalTextRequirements
            if missing.isEmpty {
                return .available(schemaFingerprint: schema.fingerprint)
            }
            return .unsupportedSchema(schemaFingerprint: schema.fingerprint, missing: missing)
        } catch MessageBridgeError.databaseUnavailable {
            return .unavailable
        } catch MessageBridgeError.databaseOpenFailed(let code) {
            if code == SQLITE_AUTH || code == SQLITE_PERM {
                return .permissionRequired
            }
            return .failed(sqliteCode: code)
        } catch MessageBridgeError.queryFailed(let code, _) {
            if code == SQLITE_AUTH || code == SQLITE_PERM {
                return .permissionRequired
            }
            return .failed(sqliteCode: code)
        } catch {
            return .failed(sqliteCode: -1)
        }
    }
}
