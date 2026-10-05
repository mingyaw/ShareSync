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
        self.senderLabels = senderLabels.reduce(into: [:]) { result, entry in
            result[MessageSenderIdentifier.canonical(entry.key)] = entry.value
        }
        self.includeAttachmentSummary = includeAttachmentSummary
    }

    public func build(from event: NormalizedMessageEvent) -> MessageConnectorEnvelope {
        MessageConnectorEnvelope(
            deliveryKey: event.deliveryKey,
            body: event.body,
            timestamp: event.timestamp,
            senderLabel: event.senderIdentifier.flatMap {
                senderLabels[MessageSenderIdentifier.canonical($0)]
            },
            hasAttachments: event.contentKinds.contains(.attachment),
            attachmentCount: includeAttachmentSummary ? event.attachmentCount : 0,
            attachmentMIMETypes: includeAttachmentSummary ? event.attachmentMIMETypes : [],
            containsRichText: event.contentKinds.contains(.richText)
        )
    }
}
