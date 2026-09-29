import CryptoKit
import Foundation

public enum MessageDirection: String, Codable, Sendable {
    case incoming
    case outgoing
}

public enum MessageContentKind: String, Codable, Hashable, Sendable {
    case text
    case richText
    case attachment
    case associatedEvent
}

public struct NormalizedMessageEvent: Equatable, Sendable {
    public let deliveryKey: String
    public let sourceRowID: Int64
    public let sourceGUID: String
    public let body: String?
    public let timestamp: Date
    public let direction: MessageDirection
    public let senderIdentifier: String?
    public let conversationIdentifiers: Set<String>
    public let service: String?
    public let contentKinds: Set<MessageContentKind>
    public let associatedMessageGUID: String?
}

public struct MessageEventNormalizer {
    public init() {}

    public func normalize(_ event: MessageEvent) -> NormalizedMessageEvent {
        var contentKinds: Set<MessageContentKind> = []
        if event.body != nil { contentKinds.insert(.text) }
        if event.hasAttributedBody { contentKinds.insert(.richText) }
        if event.hasAttachments { contentKinds.insert(.attachment) }
        if event.associatedMessageType != 0 { contentKinds.insert(.associatedEvent) }

        return NormalizedMessageEvent(
            deliveryKey: deliveryKey(guid: event.guid, rowID: event.rowID),
            sourceRowID: event.rowID,
            sourceGUID: event.guid,
            body: event.body,
            timestamp: Self.messageDate(rawValue: event.rawDate),
            direction: event.isFromMe ? .outgoing : .incoming,
            senderIdentifier: event.senderIdentifier,
            conversationIdentifiers: Set(event.conversationIdentifiers),
            service: event.service,
            contentKinds: contentKinds,
            associatedMessageGUID: event.associatedMessageGUID
        )
    }

    static func messageDate(rawValue: Int64) -> Date {
        let magnitude = rawValue == Int64.min ? Int64.max : abs(rawValue)
        let seconds = magnitude > 10_000_000_000
            ? Double(rawValue) / 1_000_000_000
            : Double(rawValue)
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    private func deliveryKey(guid: String, rowID: Int64) -> String {
        let source = Data("sharesync-message-v1:\(guid):\(rowID)".utf8)
        return SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
    }
}
