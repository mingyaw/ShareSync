import Foundation
import SQLite3

final class SQLiteReadOnlyDatabase {
    private var connection: OpaquePointer?

    init(url: URL) throws {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            throw MessageBridgeError.databaseUnavailable
        }

        let result = sqlite3_open_v2(
            url.path,
            &connection,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard result == SQLITE_OK else {
            sqlite3_close(connection)
            connection = nil
            throw MessageBridgeError.databaseOpenFailed(code: result)
        }
    }

    deinit {
        sqlite3_close(connection)
    }

    func stringValues(sql: String) throws -> [String] {
        var statement: OpaquePointer?
        try prepare(sql: sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        var values: [String] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return values }
            guard result == SQLITE_ROW else { throw queryError(code: result) }
            if let value = sqlite3_column_text(statement, 0) {
                values.append(String(cString: value))
            }
        }
    }

    func int64Value(sql: String) throws -> Int64 {
        var statement: OpaquePointer?
        try prepare(sql: sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW else {
            if result == SQLITE_DONE { return 0 }
            throw queryError(code: result)
        }
        return sqlite3_column_int64(statement, 0)
    }

    func columnNames(table: String) throws -> [String] {
        var statement: OpaquePointer?
        try prepare(sql: "PRAGMA table_info(\"\(table)\")", statement: &statement)
        defer { sqlite3_finalize(statement) }

        var values: [String] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return values }
            guard result == SQLITE_ROW else { throw queryError(code: result) }
            if let value = sqlite3_column_text(statement, 1) {
                values.append(String(cString: value))
            }
        }
    }

    func messageRows(
        after rowID: Int64,
        limit: Int,
        includeConversationContext: Bool,
        includeAttachmentMetadata: Bool
    ) throws -> [MessageEvent] {
        let conversationExpression = includeConversationContext
            ? """
              (SELECT GROUP_CONCAT(chat.guid, CHAR(31))
               FROM chat_message_join
               JOIN chat ON chat.ROWID = chat_message_join.chat_id
               WHERE chat_message_join.message_id = message.ROWID)
              """
            : "NULL"
        let attachmentCountExpression = includeAttachmentMetadata
            ? """
              (SELECT COUNT(*)
               FROM message_attachment_join
               WHERE message_attachment_join.message_id = message.ROWID)
              """
            : "0"
        let attachmentTypesExpression = includeAttachmentMetadata
            ? """
              (SELECT GROUP_CONCAT(attachment.mime_type, CHAR(31))
               FROM message_attachment_join
               JOIN attachment ON attachment.ROWID = message_attachment_join.attachment_id
               WHERE message_attachment_join.message_id = message.ROWID
                 AND attachment.mime_type IS NOT NULL)
              """
            : "NULL"
        let sql = """
        SELECT
            message.ROWID,
            message.guid,
            message.text,
            message.date,
            message.is_from_me,
            message.service,
            message.cache_has_attachments,
            message.associated_message_type,
            message.associated_message_guid,
            message.attributedBody,
            handle.id,
            \(conversationExpression),
            \(attachmentCountExpression),
            \(attachmentTypesExpression)
        FROM message
        LEFT JOIN handle ON handle.ROWID = message.handle_id
        WHERE message.ROWID > ?
        ORDER BY message.ROWID ASC
        LIMIT ?
        """
        var statement: OpaquePointer?
        try prepare(sql: sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, rowID)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var events: [MessageEvent] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return events }
            guard result == SQLITE_ROW else { throw queryError(code: result) }
            events.append(MessageEvent(
                rowID: sqlite3_column_int64(statement, 0),
                guid: string(statement, column: 1) ?? "",
                body: string(statement, column: 2),
                rawDate: sqlite3_column_int64(statement, 3),
                isFromMe: sqlite3_column_int(statement, 4) != 0,
                service: string(statement, column: 5),
                hasAttachments: sqlite3_column_int(statement, 6) != 0,
                associatedMessageType: sqlite3_column_int64(statement, 7),
                associatedMessageGUID: string(statement, column: 8),
                hasAttributedBody: sqlite3_column_type(statement, 9) != SQLITE_NULL,
                attributedBodyData: data(statement, column: 9),
                senderIdentifier: string(statement, column: 10),
                conversationIdentifiers: separatedStrings(statement, column: 11),
                attachmentCount: Int(sqlite3_column_int64(statement, 12)),
                attachmentMIMETypes: Set(separatedStrings(statement, column: 13))
            ))
        }
    }

    private func prepare(sql: String, statement: inout OpaquePointer?) throws {
        let result = sqlite3_prepare_v2(connection, sql, -1, &statement, nil)
        guard result == SQLITE_OK else { throw queryError(code: result) }
    }

    private func string(_ statement: OpaquePointer?, column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, column) else {
            return nil
        }
        return String(cString: value)
    }

    private func data(_ statement: OpaquePointer?, column: Int32) -> Data? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL,
              let bytes = sqlite3_column_blob(statement, column) else {
            return nil
        }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
    }

    private func separatedStrings(_ statement: OpaquePointer?, column: Int32) -> [String] {
        guard let joined = string(statement, column: column), !joined.isEmpty else { return [] }
        return joined.split(separator: "\u{1F}").map(String.init).sorted()
    }

    private func queryError(code: Int32) -> MessageBridgeError {
        let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
        return .queryFailed(code: code, message: message)
    }
}
