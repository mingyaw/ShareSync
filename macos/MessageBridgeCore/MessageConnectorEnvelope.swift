import Foundation

public enum MessageSenderIdentifier {
    public static func canonical(_ identifier: String) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if trimmed.contains("@") {
            return trimmed.folding(
                options: [.caseInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            ).lowercased(with: Locale(identifier: "en_US_POSIX"))
        }

        var digits = ""
        var hasLeadingPlus = false
        for character in trimmed {
            if let value = character.wholeNumberValue, (0...9).contains(value) {
                digits.append(String(value))
            } else if character == "+", digits.isEmpty, !hasLeadingPlus {
                hasLeadingPlus = true
            } else if character.isWhitespace || "()-.".contains(character) {
                continue
            } else {
                return trimmed
            }
        }
        guard digits.count >= 3 else { return trimmed }
        return (hasLeadingPlus ? "+" : "") + digits
    }
}

public struct MessageConnectorEnvelope: Equatable, Sendable {
    public let deliveryKey: String
    public let body: String?
    public let timestamp: Date
    public let senderLabel: String?
    public let replyRecipientHandle: String?
    public let hasAttachments: Bool
    public let attachmentCount: Int
    public let attachmentMIMETypes: Set<String>
    public let containsRichText: Bool

    public init(
        deliveryKey: String,
        body: String?,
        timestamp: Date,
        senderLabel: String?,
        replyRecipientHandle: String? = nil,
        hasAttachments: Bool,
        attachmentCount: Int,
        attachmentMIMETypes: Set<String>,
        containsRichText: Bool
    ) {
        self.deliveryKey = deliveryKey
        self.body = body
        self.timestamp = timestamp
        self.senderLabel = senderLabel
        self.replyRecipientHandle = replyRecipientHandle
        self.hasAttachments = hasAttachments
        self.attachmentCount = attachmentCount
        self.attachmentMIMETypes = attachmentMIMETypes
        self.containsRichText = containsRichText
    }
}

public struct MessageConnectorEnvelopeBuilder: Sendable {
    private let senderLabels: [String: String]
    private let includeAttachmentSummary: Bool
    private let includeReplyRouting: Bool

    public init(
        senderLabels: [String: String] = [:],
        includeAttachmentSummary: Bool = true,
        includeReplyRouting: Bool = false
    ) {
        self.senderLabels = senderLabels.reduce(into: [:]) { result, entry in
            result[MessageSenderIdentifier.canonical(entry.key)] = entry.value
        }
        self.includeAttachmentSummary = includeAttachmentSummary
        self.includeReplyRouting = includeReplyRouting
    }

    public func build(from event: NormalizedMessageEvent) -> MessageConnectorEnvelope {
        MessageConnectorEnvelope(
            deliveryKey: event.deliveryKey,
            body: event.body,
            timestamp: event.timestamp,
            senderLabel: event.senderIdentifier.flatMap {
                senderLabels[MessageSenderIdentifier.canonical($0)]
            },
            replyRecipientHandle: includeReplyRouting ? event.senderIdentifier.flatMap {
                let canonical = MessageSenderIdentifier.canonical($0)
                return canonical.isEmpty ? nil : canonical
            } : nil,
            hasAttachments: event.contentKinds.contains(.attachment),
            attachmentCount: includeAttachmentSummary ? event.attachmentCount : 0,
            attachmentMIMETypes: includeAttachmentSummary ? event.attachmentMIMETypes : [],
            containsRichText: event.contentKinds.contains(.richText)
        )
    }
}
