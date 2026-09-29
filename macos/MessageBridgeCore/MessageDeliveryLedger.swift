import Foundation

public enum MessageDeliveryState: String, Codable, Equatable, Sendable {
    case pending
    case delivered
}

public struct MessageDeliveryRecord: Codable, Equatable, Sendable {
    public let state: MessageDeliveryState
    public let updatedAt: Date
}

public protocol MessageDeliveryLedgerStore: AnyObject {
    func record(for deliveryKey: String) throws -> MessageDeliveryRecord?
    func markPending(deliveryKey: String, at date: Date) throws
    func markDelivered(deliveryKey: String, at date: Date) throws
    func pruneDelivered(before date: Date) throws
    func clear() throws
}

public final class InMemoryMessageDeliveryLedgerStore: MessageDeliveryLedgerStore {
    public private(set) var records: [String: MessageDeliveryRecord] = [:]

    public init() {}

    public func record(for deliveryKey: String) throws -> MessageDeliveryRecord? {
        records[deliveryKey]
    }

    public func markPending(deliveryKey: String, at date: Date) throws {
        records[deliveryKey] = MessageDeliveryRecord(state: .pending, updatedAt: date)
    }

    public func markDelivered(deliveryKey: String, at date: Date) throws {
        records[deliveryKey] = MessageDeliveryRecord(state: .delivered, updatedAt: date)
    }

    public func pruneDelivered(before date: Date) throws {
        records = records.filter { _, record in
            record.state != .delivered || record.updatedAt >= date
        }
    }

    public func clear() throws {
        records.removeAll()
    }
}

public final class FileMessageDeliveryLedgerStore: MessageDeliveryLedgerStore {
    private struct Envelope: Codable {
        let version: Int
        var records: [String: MessageDeliveryRecord]
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    public func record(for deliveryKey: String) throws -> MessageDeliveryRecord? {
        try load().records[deliveryKey]
    }

    public func markPending(deliveryKey: String, at date: Date) throws {
        var envelope = try load()
        if envelope.records[deliveryKey]?.state != .delivered {
            envelope.records[deliveryKey] = MessageDeliveryRecord(state: .pending, updatedAt: date)
            try save(envelope)
        }
    }

    public func markDelivered(deliveryKey: String, at date: Date) throws {
        var envelope = try load()
        envelope.records[deliveryKey] = MessageDeliveryRecord(state: .delivered, updatedAt: date)
        try save(envelope)
    }

    public func pruneDelivered(before date: Date) throws {
        var envelope = try load()
        envelope.records = envelope.records.filter { _, record in
            record.state != .delivered || record.updatedAt >= date
        }
        try save(envelope)
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    private func load() throws -> Envelope {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return Envelope(version: 1, records: [:])
        }
        let envelope = try decoder.decode(Envelope.self, from: Data(contentsOf: fileURL))
        guard envelope.version == 1 else {
            throw MessageDeliveryLedgerError.unsupportedVersion(envelope.version)
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

public enum MessageDeliveryLedgerError: Error, Equatable {
    case unsupportedVersion(Int)
}
