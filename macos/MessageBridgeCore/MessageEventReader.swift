import Foundation

public struct MessageCursor: Codable, Equatable, Sendable {
    public let rowID: Int64

    public init(rowID: Int64) {
        self.rowID = rowID
    }
}

public struct MessageEvent: Equatable, Sendable {
    public let rowID: Int64
    public let guid: String
    public let body: String?
    public let rawDate: Int64
    public let isFromMe: Bool
    public let service: String?
    public let hasAttachments: Bool
    public let associatedMessageType: Int64
    public let associatedMessageGUID: String?
    public let hasAttributedBody: Bool
    public let senderIdentifier: String?

    public var needsRichBodyDecoding: Bool {
        body == nil && hasAttributedBody
    }
}

public struct MessageEventBatch: Equatable, Sendable {
    public let events: [MessageEvent]
    public let nextCursor: MessageCursor
}

public protocol MessageEventReading {
    func baselineCursor() throws -> MessageCursor
    func events(after cursor: MessageCursor, limit: Int) throws -> MessageEventBatch
}

public struct MessageEventReader: MessageEventReading {
    private let databaseURL: URL

    public init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    public func baselineCursor() throws -> MessageCursor {
        let schema = try MessageDatabaseSchemaInspector().inspect(databaseURL: databaseURL)
        try validate(schema)
        let database = try SQLiteReadOnlyDatabase(url: databaseURL)
        return MessageCursor(rowID: try database.int64Value(sql: "SELECT IFNULL(MAX(ROWID), 0) FROM message"))
    }

    public func events(after cursor: MessageCursor, limit: Int = 100) throws -> MessageEventBatch {
        let schema = try MessageDatabaseSchemaInspector().inspect(databaseURL: databaseURL)
        try validate(schema)
        let boundedLimit = min(max(limit, 1), 500)
        let database = try SQLiteReadOnlyDatabase(url: databaseURL)
        let events = try database.messageRows(after: cursor.rowID, limit: boundedLimit)
        return MessageEventBatch(
            events: events,
            nextCursor: MessageCursor(rowID: events.last?.rowID ?? cursor.rowID)
        )
    }

    private func validate(_ schema: MessageDatabaseSchema) throws {
        let missing = schema.missingIncrementalTextRequirements
        guard missing.isEmpty else {
            throw MessageBridgeError.unsupportedSchema(missing: missing)
        }
    }
}
