import Foundation

public struct MessageConnectorEnvelope: Equatable, Sendable {
    public let deliveryKey: String
    public let body: String?
    public let timestamp: Date
    public let senderLabel: String?
    public let hasAttachments: Bool
    public let attachmentCount: Int
    public let attachmentMIMETypes: Set<String>
    public let containsRichText: Bool
}

public struct MessageConnectorEnvelopeBuilder: Sendable {
    private let senderLabels: [String: String]
    private let includeAttachmentSummary: Bool

    public init(
        senderLabels: [String: String] = [:],
        includeAttachmentSummary: Bool = true
    ) {
        self.senderLabels = senderLabels
        self.includeAttachmentSummary = includeAttachmentSummary
    }

    public func build(from event: NormalizedMessageEvent) -> MessageConnectorEnvelope {
        MessageConnectorEnvelope(
            deliveryKey: event.deliveryKey,
            body: event.body,
            timestamp: event.timestamp,
            senderLabel: event.senderIdentifier.flatMap { senderLabels[$0] },
            hasAttachments: event.contentKinds.contains(.attachment),
            attachmentCount: includeAttachmentSummary ? event.attachmentCount : 0,
            attachmentMIMETypes: includeAttachmentSummary ? event.attachmentMIMETypes : [],
            containsRichText: event.contentKinds.contains(.richText)
        )
    }
}
