import CryptoKit
import Foundation

public protocol MessageAttachmentForwardingConnector: AnyObject {
    func deliver(_ attachment: LoadedMessageAttachment) throws
}

public struct MessageAttachmentDeliveryResult: Equatable, Sendable {
    public let deliveredCount: Int
    public let duplicateCount: Int
    public let unconfirmedCount: Int

    public init(deliveredCount: Int, duplicateCount: Int, unconfirmedCount: Int = 0) {
        self.deliveredCount = deliveredCount
        self.duplicateCount = duplicateCount
        self.unconfirmedCount = unconfirmedCount
    }
}

public enum MessageAttachmentDeliveryError: Error, Equatable, Sendable {
    case deliveryUnconfirmed
}

public struct MessageAttachmentDeliveryCoordinator {
    private let accessCoordinator: MessageAttachmentAccessCoordinator
    private let connector: any MessageAttachmentForwardingConnector

    public init(
        accessCoordinator: MessageAttachmentAccessCoordinator,
        connector: any MessageAttachmentForwardingConnector
    ) {
        self.accessCoordinator = accessCoordinator
        self.connector = connector
    }

    public func deliverAttachments(
        for event: NormalizedMessageEvent,
        ledger: any MessageDeliveryLedgerStore,
        at date: Date
    ) throws -> MessageAttachmentDeliveryResult {
        let attachments = try accessCoordinator.loadAttachments(for: event)
        var deliveredCount = 0
        var duplicateCount = 0
        var unconfirmedCount = 0

        for (index, attachment) in attachments.enumerated() {
            let partKey = MessageDeliveryPartKey.attachment(
                messageKey: event.deliveryKey,
                index: index
            )
            if try ledger.record(for: partKey)?.state == .delivered {
                duplicateCount += 1
                continue
            }
            if try ledger.record(for: partKey)?.state == .pending {
                unconfirmedCount += 1
                continue
            }
            try ledger.markPending(deliveryKey: partKey, at: date)
            do {
                try connector.deliver(attachment)
            } catch let error as TelegramBotConnectorError {
                if error.isDefinitiveRejection {
                    try ledger.remove(deliveryKey: partKey)
                    throw error
                }
                throw MessageAttachmentDeliveryError.deliveryUnconfirmed
            } catch let error as MessageAttachmentValidationError {
                try ledger.remove(deliveryKey: partKey)
                throw error
            } catch {
                throw MessageAttachmentDeliveryError.deliveryUnconfirmed
            }
            try ledger.markDelivered(deliveryKey: partKey, at: date)
            deliveredCount += 1
        }
        return MessageAttachmentDeliveryResult(
            deliveredCount: deliveredCount,
            duplicateCount: duplicateCount,
            unconfirmedCount: unconfirmedCount
        )
    }
}

private extension TelegramBotConnectorError {
    var isDefinitiveRejection: Bool {
        switch self {
        case .invalidToken, .invalidChatID, .apiFailure, .rateLimited:
            return true
        case .invalidResponse, .requestTimedOut, .transportFailure:
            return false
        }
    }
}

enum MessageDeliveryPartKey {
    static func text(messageKey: String) -> String {
        digest("sharesync-message-part-v1:\(messageKey):text")
    }

    static func attachment(messageKey: String, index: Int) -> String {
        digest("sharesync-message-part-v1:\(messageKey):attachment:\(index)")
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
