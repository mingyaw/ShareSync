import Foundation
import SQLite3

final class MessageBridgeFixture {
    let directoryURL: URL
    let databaseURL: URL
    private var connection: OpaquePointer?

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        databaseURL = directoryURL.appendingPathComponent("chat.db")
        guard sqlite3_open(databaseURL.path, &connection) == SQLITE_OK else {
            throw FixtureError.openFailed
        }
        try execute("""
        CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
        CREATE TABLE message (
            ROWID INTEGER PRIMARY KEY,
            guid TEXT,
            text TEXT,
            attributedBody BLOB,
            date INTEGER,
            is_from_me INTEGER,
            handle_id INTEGER,
            service TEXT,
            cache_has_attachments INTEGER,
            associated_message_type INTEGER,
            associated_message_guid TEXT
        );
        CREATE TABLE chat (ROWID INTEGER PRIMARY KEY, guid TEXT);
        CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
        CREATE TABLE attachment (ROWID INTEGER PRIMARY KEY, mime_type TEXT);
        CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER);
        """)
    }

    deinit {
        sqlite3_close(connection)
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func insertHandle(rowID: Int64 = 1, identifier: String = "synthetic-sender") throws {
        try execute("INSERT INTO handle (ROWID, id) VALUES (\(rowID), '\(escaped(identifier))')")
    }

    func insertMessage(
        guid: String,
        body: String?,
        attributedBody: Data? = nil,
        date: Int64 = 1,
        isFromMe: Bool = false,
        hasAttachments: Bool = false,
        associatedType: Int64 = 0,
        associatedGUID: String? = nil
    ) throws {
        let textValue = body.map { "'\(escaped($0))'" } ?? "NULL"
        let richValue = attributedBody.map { "X'\($0.map { String(format: "%02x", $0) }.joined())'" } ?? "NULL"
        let associatedValue = associatedGUID.map { "'\(escaped($0))'" } ?? "NULL"
        try execute("""
        INSERT INTO message (
            guid, text, attributedBody, date, is_from_me, handle_id, service,
            cache_has_attachments, associated_message_type, associated_message_guid
        ) VALUES (
            '\(escaped(guid))', \(textValue), \(richValue), \(date), \(isFromMe ? 1 : 0), 1,
            'iMessage', \(hasAttachments ? 1 : 0), \(associatedType), \(associatedValue)
        )
        """)
    }

    func insertChat(rowID: Int64 = 1, guid: String = "synthetic-conversation") throws {
        try execute("INSERT INTO chat (ROWID, guid) VALUES (\(rowID), '\(escaped(guid))')")
    }

    func linkMessage(rowID: Int64, toChat chatRowID: Int64 = 1) throws {
        try execute("INSERT INTO chat_message_join (chat_id, message_id) VALUES (\(chatRowID), \(rowID))")
    }

    func insertAttachment(rowID: Int64 = 1, mimeType: String?) throws {
        let mimeValue = mimeType.map { "'\(escaped($0))'" } ?? "NULL"
        try execute("INSERT INTO attachment (ROWID, mime_type) VALUES (\(rowID), \(mimeValue))")
    }

    func linkAttachment(rowID: Int64, toMessage messageRowID: Int64) throws {
        try execute(
            "INSERT INTO message_attachment_join (message_id, attachment_id) VALUES (\(messageRowID), \(rowID))"
        )
    }

    func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(connection, sql, nil, nil, &error)
        guard result == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw FixtureError.queryFailed(message)
        }
    }

    private func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    enum FixtureError: Error {
        case openFailed
        case queryFailed(String)
    }
}
