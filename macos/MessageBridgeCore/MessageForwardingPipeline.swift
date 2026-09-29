import Foundation

public struct MessageForwardingPolicy: Equatable, Sendable {
    public let allowedSenderIdentifiers: Set<String>
    public let allowedConversationIdentifiers: Set<String>?
    public let allowedServices: Set<String>
    public let incomingOnly: Bool
    public let allowAssociatedEvents: Bool

    public init(
        allowedSenderIdentifiers: Set<String>,
        allowedConversationIdentifiers: Set<String>? = nil,
        allowedServices: Set<String> = ["iMessage"],
        incomingOnly: Bool = true,
        allowAssociatedEvents: Bool = false
    ) {
        self.allowedSenderIdentifiers = allowedSenderIdentifiers
        self.allowedConversationIdentifiers = allowedConversationIdentifiers
        self.allowedServices = allowedServices
        self.incomingOnly = incomingOnly
        self.allowAssociatedEvents = allowAssociatedEvents
    }

    public func permits(_ event: NormalizedMessageEvent) -> Bool {
        guard let sender = event.senderIdentifier,
              allowedSenderIdentifiers.contains(sender),
              let service = event.service,
              allowedServices.contains(service) else {
            return false
        }
        if incomingOnly && event.direction != .incoming { return false }
        if let allowedConversationIdentifiers,
           event.conversationIdentifiers.isDisjoint(with: allowedConversationIdentifiers) {
            return false
        }
        if !allowAssociatedEvents && event.contentKinds.contains(.associatedEvent) { return false }
        return !event.contentKinds.isEmpty
    }
}

public enum MessageDeliveryOutcome: Equatable, Sendable {
    case delivered
    case duplicate
}

public protocol MessageForwardingConnector: AnyObject {
    func deliver(_ event: NormalizedMessageEvent) throws -> MessageDeliveryOutcome
}

public final class InMemoryMessageForwardingConnector: MessageForwardingConnector {
    public private(set) var deliveries: [NormalizedMessageEvent] = []
    private var deliveredKeys: Set<String> = []

    public init() {}

    public func deliver(_ event: NormalizedMessageEvent) throws -> MessageDeliveryOutcome {
        guard deliveredKeys.insert(event.deliveryKey).inserted else { return .duplicate }
        deliveries.append(event)
        return .delivered
    }
}

public struct MessageForwardingRunResult: Equatable, Sendable {
    public let inspectedCount: Int
    public let eligibleCount: Int
    public let deliveredCount: Int
    public let duplicateCount: Int
    public let nextCursor: MessageCursor
}

public struct MessageForwardingPipeline {
    private let reader: any MessageEventReading
    private let cursorStore: any MessageCursorStore
    private let normalizer: MessageEventNormalizer
    private let policy: MessageForwardingPolicy
    private let connector: any MessageForwardingConnector

    public init(
        reader: any MessageEventReading,
        cursorStore: any MessageCursorStore,
        normalizer: MessageEventNormalizer = MessageEventNormalizer(),
        policy: MessageForwardingPolicy,
        connector: any MessageForwardingConnector
    ) {
        self.reader = reader
        self.cursorStore = cursorStore
        self.normalizer = normalizer
        self.policy = policy
        self.connector = connector
    }

    public func run(limit: Int = 100) throws -> MessageForwardingRunResult {
        guard let cursor = try cursorStore.load() else {
            throw MessageValidationSessionError.baselineRequired
        }

        let batch = try reader.events(after: cursor, limit: limit)
        var eligibleCount = 0
        var deliveredCount = 0
        var duplicateCount = 0

        for sourceEvent in batch.events {
            let event = normalizer.normalize(sourceEvent)
            guard policy.permits(event) else { continue }
            eligibleCount += 1
            switch try connector.deliver(event) {
            case .delivered: deliveredCount += 1
            case .duplicate: duplicateCount += 1
            }
        }

        if batch.nextCursor != cursor {
            try cursorStore.save(batch.nextCursor)
        }
        return MessageForwardingRunResult(
            inspectedCount: batch.events.count,
            eligibleCount: eligibleCount,
            deliveredCount: deliveredCount,
            duplicateCount: duplicateCount,
            nextCursor: batch.nextCursor
        )
    }
}
