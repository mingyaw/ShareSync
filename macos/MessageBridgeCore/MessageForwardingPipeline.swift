import Foundation

public struct MessageForwardingPolicy: Equatable, Sendable {
    public let allowedSenderIdentifiers: Set<String>
    public let allowedConversationIdentifiers: Set<String>?
    public let allowedServices: Set<String>
    public let incomingOnly: Bool
    public let allowAssociatedEvents: Bool
    public let blockedBodyTerms: Set<String>
    public let blockLikelyOneTimeCodes: Bool

    public init(
        allowedSenderIdentifiers: Set<String>,
        allowedConversationIdentifiers: Set<String>? = nil,
        allowedServices: Set<String> = ["iMessage"],
        incomingOnly: Bool = true,
        allowAssociatedEvents: Bool = false,
        blockedBodyTerms: Set<String> = [],
        blockLikelyOneTimeCodes: Bool = true
    ) {
        self.allowedSenderIdentifiers = allowedSenderIdentifiers
        self.allowedConversationIdentifiers = allowedConversationIdentifiers
        self.allowedServices = allowedServices
        self.incomingOnly = incomingOnly
        self.allowAssociatedEvents = allowAssociatedEvents
        self.blockedBodyTerms = Set(blockedBodyTerms.map { $0.foldingForComparison })
        self.blockLikelyOneTimeCodes = blockLikelyOneTimeCodes
    }

    public func permits(_ event: NormalizedMessageEvent) -> Bool {
        evaluate(event) == .allow
    }

    public func evaluate(_ event: NormalizedMessageEvent) -> MessageForwardingDecision {
        if incomingOnly && event.direction != .incoming { return .deny(.outgoingMessage) }
        guard let sender = event.senderIdentifier,
              allowedSenderIdentifiers.contains(sender) else { return .deny(.senderNotAllowed) }
        guard let service = event.service,
              allowedServices.contains(service) else { return .deny(.serviceNotAllowed) }
        if let allowedConversationIdentifiers,
           event.conversationIdentifiers.isDisjoint(with: allowedConversationIdentifiers) {
            return .deny(.conversationNotAllowed)
        }
        if !allowAssociatedEvents && event.contentKinds.contains(.associatedEvent) {
            return .deny(.associatedEventBlocked)
        }
        guard !event.contentKinds.isEmpty else { return .deny(.emptyContent) }
        if let body = event.body, isSensitive(body) { return .deny(.sensitiveContent) }
        return .allow
    }

    private func isSensitive(_ body: String) -> Bool {
        let foldedBody = body.foldingForComparison
        if blockedBodyTerms.contains(where: foldedBody.contains) { return true }
        guard blockLikelyOneTimeCodes else { return false }
        let keywords = ["otp", "code", "passcode", "verification", "驗證碼", "動態密碼", "一次性密碼"]
        guard keywords.contains(where: foldedBody.contains) else { return false }
        return foldedBody.range(of: #"(?<!\d)\d{4,8}(?!\d)"#, options: .regularExpression) != nil
    }
}

public enum MessageForwardingDenialReason: String, Codable, Hashable, Sendable {
    case senderNotAllowed
    case serviceNotAllowed
    case outgoingMessage
    case conversationNotAllowed
    case associatedEventBlocked
    case emptyContent
    case sensitiveContent
}

public enum MessageForwardingDecision: Equatable, Sendable {
    case allow
    case deny(MessageForwardingDenialReason)
}

public enum MessageDeliveryOutcome: Equatable, Sendable {
    case delivered
    case duplicate
}

public protocol MessageForwardingConnector: AnyObject {
    func deliver(_ envelope: MessageConnectorEnvelope) throws -> MessageDeliveryOutcome
}

public final class InMemoryMessageForwardingConnector: MessageForwardingConnector {
    public private(set) var deliveries: [MessageConnectorEnvelope] = []
    private var deliveredKeys: Set<String> = []

    public init() {}

    public func deliver(_ envelope: MessageConnectorEnvelope) throws -> MessageDeliveryOutcome {
        guard deliveredKeys.insert(envelope.deliveryKey).inserted else { return .duplicate }
        deliveries.append(envelope)
        return .delivered
    }
}

public struct MessageForwardingRunResult: Equatable, Sendable {
    public let inspectedCount: Int
    public let eligibleCount: Int
    public let deliveredCount: Int
    public let duplicateCount: Int
    public let deniedCounts: [MessageForwardingDenialReason: Int]
    public let nextCursor: MessageCursor

    public var preventedLoopCount: Int {
        deniedCounts[.outgoingMessage, default: 0]
    }
}

public enum MessageForwardingPipelineError: Error, Equatable, Sendable {
    case rateLimited(retryAfter: TimeInterval)
}

public struct MessageForwardingPipeline {
    private let reader: any MessageEventReading
    private let cursorStore: any MessageCursorStore
    private let normalizer: MessageEventNormalizer
    private let policy: MessageForwardingPolicy
    private let connector: any MessageForwardingConnector
    private let runtimeGate: MessageForwardingRuntimeGate
    private let deliveryLedger: any MessageDeliveryLedgerStore
    private let rateLimiter: MessageDeliveryRateLimiter?
    private let envelopeBuilder: MessageConnectorEnvelopeBuilder
    private let now: () -> Date

    public init(
        reader: any MessageEventReading,
        cursorStore: any MessageCursorStore,
        normalizer: MessageEventNormalizer = MessageEventNormalizer(),
        policy: MessageForwardingPolicy,
        connector: any MessageForwardingConnector,
        runtimeGate: MessageForwardingRuntimeGate = MessageForwardingRuntimeGate(),
        deliveryLedger: any MessageDeliveryLedgerStore = InMemoryMessageDeliveryLedgerStore(),
        rateLimiter: MessageDeliveryRateLimiter? = nil,
        envelopeBuilder: MessageConnectorEnvelopeBuilder = MessageConnectorEnvelopeBuilder(),
        now: @escaping () -> Date = Date.init
    ) {
        self.reader = reader
        self.cursorStore = cursorStore
        self.normalizer = normalizer
        self.policy = policy
        self.connector = connector
        self.runtimeGate = runtimeGate
        self.deliveryLedger = deliveryLedger
        self.rateLimiter = rateLimiter
        self.envelopeBuilder = envelopeBuilder
        self.now = now
    }

    public func run(limit: Int = 100) throws -> MessageForwardingRunResult {
        try runtimeGate.validate(at: now())
        guard let cursor = try cursorStore.load() else {
            throw MessageValidationSessionError.baselineRequired
        }

        let batch = try reader.events(after: cursor, limit: limit)
        var eligibleCount = 0
        var deliveredCount = 0
        var duplicateCount = 0
        var deniedCounts: [MessageForwardingDenialReason: Int] = [:]

        for sourceEvent in batch.events {
            let event = normalizer.normalize(sourceEvent)
            switch policy.evaluate(event) {
            case .allow:
                break
            case .deny(let reason):
                deniedCounts[reason, default: 0] += 1
                continue
            }
            eligibleCount += 1
            if try deliveryLedger.record(for: event.deliveryKey)?.state == .delivered {
                duplicateCount += 1
                continue
            }
            let deliveryDate = now()
            if let rateLimiter,
               case .limited(let retryAfter) = rateLimiter.reserve(at: deliveryDate) {
                throw MessageForwardingPipelineError.rateLimited(retryAfter: retryAfter)
            }
            try deliveryLedger.markPending(deliveryKey: event.deliveryKey, at: deliveryDate)
            let envelope = envelopeBuilder.build(from: event)
            switch try connector.deliver(envelope) {
            case .delivered:
                deliveredCount += 1
            case .duplicate:
                duplicateCount += 1
            }
            try deliveryLedger.markDelivered(deliveryKey: event.deliveryKey, at: now())
        }

        if batch.nextCursor != cursor {
            try cursorStore.save(batch.nextCursor)
        }
        return MessageForwardingRunResult(
            inspectedCount: batch.events.count,
            eligibleCount: eligibleCount,
            deliveredCount: deliveredCount,
            duplicateCount: duplicateCount,
            deniedCounts: deniedCounts,
            nextCursor: batch.nextCursor
        )
    }
}

private extension String {
    var foldingForComparison: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }
}
