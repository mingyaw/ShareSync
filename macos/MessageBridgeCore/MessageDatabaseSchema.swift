import CryptoKit
import Foundation

public struct MessageDatabaseSchema: Equatable, Sendable {
    public let tables: Set<String>
    public let columnsByTable: [String: Set<String>]
    public let fingerprint: String

    public var supportsIncrementalTextEvents: Bool {
        missingIncrementalTextRequirements.isEmpty
    }

    public var supportsConversationContext: Bool {
        let chatColumns = columnsByTable["chat"] ?? []
        let joinColumns = columnsByTable["chat_message_join"] ?? []
        return tables.contains("chat")
            && tables.contains("chat_message_join")
            && chatColumns.contains("guid")
            && joinColumns.isSuperset(of: ["chat_id", "message_id"])
    }

    public var supportsAttachmentMetadata: Bool {
        let attachmentColumns = columnsByTable["attachment"] ?? []
        let joinColumns = columnsByTable["message_attachment_join"] ?? []
        return tables.contains("attachment")
            && tables.contains("message_attachment_join")
            && attachmentColumns.contains("mime_type")
            && joinColumns.isSuperset(of: ["attachment_id", "message_id"])
    }

    public var supportsAttachmentPaths: Bool {
        missingAttachmentPathRequirements.isEmpty
    }

    public var missingAttachmentPathRequirements: [String] {
        var missing: [String] = []
        let attachmentColumns = columnsByTable["attachment"] ?? []
        let joinColumns = columnsByTable["message_attachment_join"] ?? []

        if !tables.contains("attachment") { missing.append("table:attachment") }
        if !tables.contains("message_attachment_join") {
            missing.append("table:message_attachment_join")
        }
        for column in ["filename", "mime_type"] where !attachmentColumns.contains(column) {
            missing.append("attachment.\(column)")
        }
        for column in ["attachment_id", "message_id"] where !joinColumns.contains(column) {
            missing.append("message_attachment_join.\(column)")
        }
        return missing.sorted()
    }

    public var missingIncrementalTextRequirements: [String] {
        var missing: [String] = []
        let messageColumns = columnsByTable["message"] ?? []
        let handleColumns = columnsByTable["handle"] ?? []

        if !tables.contains("message") { missing.append("table:message") }
        if !tables.contains("handle") { missing.append("table:handle") }
        for column in [
            "guid", "text", "date", "is_from_me", "service", "handle_id",
            "cache_has_attachments", "associated_message_type",
            "associated_message_guid", "attributedBody",
        ] where !messageColumns.contains(column) {
            missing.append("message.\(column)")
        }
        if !handleColumns.contains("id") { missing.append("handle.id") }
        return missing.sorted()
    }
}

public struct MessageDatabaseSchemaInspector {
    public init() {}

    public func inspect(databaseURL: URL) throws -> MessageDatabaseSchema {
        let database = try SQLiteReadOnlyDatabase(url: databaseURL)
        let tables = Set(try database.stringValues(
            sql: "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
        ))
        var columnsByTable: [String: Set<String>] = [:]
        for table in tables {
            guard Self.isSafeIdentifier(table) else { continue }
            columnsByTable[table] = Set(try database.columnNames(table: table))
        }

        let canonical = columnsByTable.keys.sorted().map { table in
            "\(table):\((columnsByTable[table] ?? []).sorted().joined(separator: ","))"
        }.joined(separator: "\n")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        let fingerprint = digest.map { String(format: "%02x", $0) }.joined()
        return MessageDatabaseSchema(
            tables: tables,
            columnsByTable: columnsByTable,
            fingerprint: fingerprint
        )
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
