import Foundation

public enum MessageForwardingAuditOutcome: String, Codable, Equatable, Sendable {
    case completed
    case paused
    case outsideSchedule
    case rateLimited
    case attachmentRejected
    case attachmentDeliveryUnconfirmed
    case messageDeliveryUnconfirmed
    case failed
}

extension MessageForwardingAuditOutcome {
    static func classify(_ error: Error) -> MessageForwardingAuditOutcome {
        switch error {
        case MessageForwardingRuntimeBlock.paused: return .paused
        case MessageForwardingRuntimeBlock.outsideSchedule: return .outsideSchedule
        case MessageForwardingPipelineError.rateLimited: return .rateLimited
        case MessageForwardingPipelineError.deliveryUnconfirmed: return .messageDeliveryUnconfirmed
        case TelegramBotConnectorError.rateLimited: return .rateLimited
        case is MessageAttachmentValidationError,
             is MessageAttachmentAccessError,
             is MessageAttachmentCandidateProviderError:
            return .attachmentRejected
        case MessageAttachmentDeliveryError.deliveryUnconfirmed:
            return .attachmentDeliveryUnconfirmed
        default: return .failed
        }
    }
}

public struct MessageForwardingAuditRecord: Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let outcome: MessageForwardingAuditOutcome
    public let inspectedCount: Int
    public let eligibleCount: Int
    public let deliveredCount: Int
    public let duplicateCount: Int
    public let unconfirmedMessageCount: Int
    public let deliveredAttachmentCount: Int
    public let duplicateAttachmentCount: Int
    public let unconfirmedAttachmentCount: Int
    public let deniedCounts: [String: Int]

    public var preventedLoopCount: Int {
        deniedCounts[MessageForwardingDenialReason.outgoingMessage.rawValue, default: 0]
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        outcome: MessageForwardingAuditOutcome,
        inspectedCount: Int = 0,
        eligibleCount: Int = 0,
        deliveredCount: Int = 0,
        duplicateCount: Int = 0,
        unconfirmedMessageCount: Int = 0,
        deliveredAttachmentCount: Int = 0,
        duplicateAttachmentCount: Int = 0,
        unconfirmedAttachmentCount: Int = 0,
        deniedCounts: [String: Int] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.outcome = outcome
        self.inspectedCount = inspectedCount
        self.eligibleCount = eligibleCount
        self.deliveredCount = deliveredCount
        self.duplicateCount = duplicateCount
        self.unconfirmedMessageCount = unconfirmedMessageCount
        self.deliveredAttachmentCount = deliveredAttachmentCount
        self.duplicateAttachmentCount = duplicateAttachmentCount
        self.unconfirmedAttachmentCount = unconfirmedAttachmentCount
        self.deniedCounts = deniedCounts
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, outcome, inspectedCount, eligibleCount, deliveredCount
        case duplicateCount, unconfirmedMessageCount, deliveredAttachmentCount, duplicateAttachmentCount
        case unconfirmedAttachmentCount, deniedCounts
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        outcome = try container.decode(MessageForwardingAuditOutcome.self, forKey: .outcome)
        inspectedCount = try container.decode(Int.self, forKey: .inspectedCount)
        eligibleCount = try container.decode(Int.self, forKey: .eligibleCount)
        deliveredCount = try container.decode(Int.self, forKey: .deliveredCount)
        duplicateCount = try container.decode(Int.self, forKey: .duplicateCount)
        unconfirmedMessageCount = try container.decodeIfPresent(
            Int.self,
            forKey: .unconfirmedMessageCount
        ) ?? 0
        deliveredAttachmentCount = try container.decodeIfPresent(
            Int.self,
            forKey: .deliveredAttachmentCount
        ) ?? 0
        duplicateAttachmentCount = try container.decodeIfPresent(
            Int.self,
            forKey: .duplicateAttachmentCount
        ) ?? 0
        unconfirmedAttachmentCount = try container.decodeIfPresent(
            Int.self,
            forKey: .unconfirmedAttachmentCount
        ) ?? 0
        deniedCounts = try container.decode([String: Int].self, forKey: .deniedCounts)
    }
}

public protocol MessageForwardingAuditStore: AnyObject {
    func append(_ record: MessageForwardingAuditRecord) throws
    func recent(limit: Int) throws -> [MessageForwardingAuditRecord]
    func clear() throws
}

public final class FileMessageForwardingAuditStore: MessageForwardingAuditStore {
    private struct Envelope: Codable {
        let version: Int
        var records: [MessageForwardingAuditRecord]
    }

    private let fileURL: URL
    private let maximumRecords: Int
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock: NSLock

    public init(
        fileURL: URL,
        maximumRecords: Int = 200,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.maximumRecords = max(maximumRecords, 1)
        self.fileManager = fileManager
        self.lock = MessageBridgeFileLockRegistry.lock(for: fileURL)
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    public func append(_ record: MessageForwardingAuditRecord) throws {
        try withMessageBridgeFileLock(lock) {
            var envelope = try load()
            envelope.records.append(record)
            if envelope.records.count > maximumRecords {
                envelope.records.removeFirst(envelope.records.count - maximumRecords)
            }
            try save(envelope)
        }
    }

    public func recent(limit: Int) throws -> [MessageForwardingAuditRecord] {
        try withMessageBridgeFileLock(lock) {
            let boundedLimit = min(max(limit, 0), maximumRecords)
            return Array(try load().records.suffix(boundedLimit).reversed())
        }
    }

    public func clear() throws {
        try withMessageBridgeFileLock(lock) {
            guard fileManager.fileExists(atPath: fileURL.path) else { return }
            try fileManager.removeItem(at: fileURL)
        }
    }

    private func load() throws -> Envelope {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return Envelope(version: 1, records: [])
        }
        let envelope = try decoder.decode(Envelope.self, from: Data(contentsOf: fileURL))
        guard envelope.version == 1 else {
            throw MessageForwardingAuditStoreError.unsupportedVersion(envelope.version)
        }
        return envelope
    }

    private func save(_ envelope: Envelope) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(envelope).write(to: fileURL, options: .atomic)
    }
}

public enum MessageForwardingAuditStoreError: Error, Equatable {
    case unsupportedVersion(Int)
}

public struct AuditedMessageForwardingRunner {
    private let pipeline: MessageForwardingPipeline
    private let auditStore: any MessageForwardingAuditStore
    private let now: () -> Date

    public init(
        pipeline: MessageForwardingPipeline,
        auditStore: any MessageForwardingAuditStore,
        now: @escaping () -> Date = Date.init
    ) {
        self.pipeline = pipeline
        self.auditStore = auditStore
        self.now = now
    }

    public func run(limit: Int = 100) throws -> MessageForwardingRunResult {
        do {
            let result = try pipeline.run(limit: limit)
            try auditStore.append(MessageForwardingAuditRecord(
                timestamp: now(),
                outcome: .completed,
                inspectedCount: result.inspectedCount,
                eligibleCount: result.eligibleCount,
                deliveredCount: result.deliveredCount,
                duplicateCount: result.duplicateCount,
                unconfirmedMessageCount: result.unconfirmedMessageCount,
                deliveredAttachmentCount: result.deliveredAttachmentCount,
                duplicateAttachmentCount: result.duplicateAttachmentCount,
                unconfirmedAttachmentCount: result.unconfirmedAttachmentCount,
                deniedCounts: Dictionary(uniqueKeysWithValues: result.deniedCounts.map {
                    ($0.key.rawValue, $0.value)
                })
            ))
            return result
        } catch {
            try auditStore.append(MessageForwardingAuditRecord(
                timestamp: now(),
                outcome: MessageForwardingAuditOutcome.classify(error)
            ))
            throw error
        }
    }
}
