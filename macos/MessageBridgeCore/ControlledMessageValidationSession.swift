import Foundation

public enum MessageValidationSessionError: Error, Equatable {
    case baselineRequired
}

public enum MessageValidationActivationResult: Equatable, Sendable {
    case baselineEstablished(MessageCursor)
    case alreadyActive(MessageCursor)
}

public struct MessageValidationSummary: Equatable, Sendable {
    public let eventCount: Int
    public let incomingCount: Int
    public let outgoingCount: Int
    public let plainTextCount: Int
    public let richBodyCount: Int
    public let attachmentCount: Int
    public let associatedEventCount: Int
    public let missingSenderCount: Int
    public let services: Set<String>

    public var isEmpty: Bool { eventCount == 0 }

    init(events: [MessageEvent]) {
        eventCount = events.count
        incomingCount = events.filter { !$0.isFromMe }.count
        outgoingCount = events.filter(\.isFromMe).count
        plainTextCount = events.filter { $0.body != nil }.count
        richBodyCount = events.filter(\.hasAttributedBody).count
        attachmentCount = events.filter(\.hasAttachments).count
        associatedEventCount = events.filter { $0.associatedMessageType != 0 }.count
        missingSenderCount = events.filter { $0.senderIdentifier == nil }.count
        services = Set(events.compactMap(\.service))
    }
}

public struct ControlledMessageValidationSession {
    private let reader: any MessageEventReading
    private let cursorStore: any MessageCursorStore

    public init(reader: any MessageEventReading, cursorStore: any MessageCursorStore) {
        self.reader = reader
        self.cursorStore = cursorStore
    }

    /// Establishes the point after which messages are eligible for validation.
    /// Existing message history is never returned by this operation.
    public func activate() throws -> MessageValidationActivationResult {
        if let cursor = try cursorStore.load() {
            return .alreadyActive(cursor)
        }

        let cursor = try reader.baselineCursor()
        try cursorStore.save(cursor)
        return .baselineEstablished(cursor)
    }

    /// Emits only aggregate field-availability information. The cursor advances
    /// after the consumer succeeds, so a failed validation can be retried.
    public func poll(
        limit: Int = 100,
        consume: (MessageValidationSummary) throws -> Void
    ) throws -> MessageValidationSummary {
        guard let cursor = try cursorStore.load() else {
            throw MessageValidationSessionError.baselineRequired
        }

        let batch = try reader.events(after: cursor, limit: limit)
        let summary = MessageValidationSummary(events: batch.events)
        guard !summary.isEmpty else { return summary }

        try consume(summary)
        try cursorStore.save(batch.nextCursor)
        return summary
    }
}
