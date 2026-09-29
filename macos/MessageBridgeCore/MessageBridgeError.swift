import Foundation

public enum MessageBridgeError: Error, Equatable, LocalizedError {
    case databaseUnavailable
    case databaseOpenFailed(code: Int32)
    case queryFailed(code: Int32, message: String)
    case unsupportedSchema(missing: [String])

    public var errorDescription: String? {
        switch self {
        case .databaseUnavailable:
            return "The selected Messages database is unavailable."
        case .databaseOpenFailed(let code):
            return "The selected Messages database could not be opened (SQLite \(code))."
        case .queryFailed(let code, let message):
            return "The Messages database query failed (SQLite \(code)): \(message)"
        case .unsupportedSchema(let missing):
            return "The Messages database schema is unsupported. Missing: \(missing.joined(separator: ", "))."
        }
    }
}
