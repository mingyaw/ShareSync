import Foundation

public struct NoteSyncReceipt: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let completedAtEpochMillis: Int64
    public let peerDeviceId: String
    public let pulledBatchId: String
    public let pushedBatchId: String
    public let changedCount: Int
    public let conflictCount: Int

    public init(
        schemaVersion: Int = NoteSyncReceipt.currentSchemaVersion,
        completedAtEpochMillis: Int64,
        peerDeviceId: String,
        pulledBatchId: String,
        pushedBatchId: String,
        changedCount: Int,
        conflictCount: Int
    ) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw NoteSyncReceiptError.unsupportedSchemaVersion(schemaVersion)
        }
        guard completedAtEpochMillis >= 0 else {
            throw NoteSyncReceiptError.invalidCompletedAt
        }
        guard !peerDeviceId.isEmpty, !pulledBatchId.isEmpty, !pushedBatchId.isEmpty else {
            throw NoteSyncReceiptError.missingIdentifier
        }
        guard changedCount >= 0, conflictCount >= 0 else {
            throw NoteSyncReceiptError.invalidCount
        }
        self.schemaVersion = schemaVersion
        self.completedAtEpochMillis = completedAtEpochMillis
        self.peerDeviceId = peerDeviceId
        self.pulledBatchId = pulledBatchId
        self.pushedBatchId = pushedBatchId
        self.changedCount = changedCount
        self.conflictCount = conflictCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            completedAtEpochMillis: container.decode(Int64.self, forKey: .completedAtEpochMillis),
            peerDeviceId: container.decode(String.self, forKey: .peerDeviceId),
            pulledBatchId: container.decode(String.self, forKey: .pulledBatchId),
            pushedBatchId: container.decode(String.self, forKey: .pushedBatchId),
            changedCount: container.decode(Int.self, forKey: .changedCount),
            conflictCount: container.decode(Int.self, forKey: .conflictCount)
        )
    }
}

public enum NoteSyncReceiptError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidCompletedAt
    case missingIdentifier
    case invalidCount
}

public protocol NoteSyncReceiptStore {
    func load() throws -> NoteSyncReceipt?
    func save(_ receipt: NoteSyncReceipt) throws
}

public final class FileNoteSyncReceiptStore: NoteSyncReceiptStore {
    public let fileURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultStoreURL(fileManager: fileManager)
    }

    public func load() throws -> NoteSyncReceipt? {
        try lock.withReceiptLock {
            guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
            return try JSONDecoder().decode(NoteSyncReceipt.self, from: Data(contentsOf: fileURL))
        }
    }

    public func save(_ receipt: NoteSyncReceipt) throws {
        try lock.withReceiptLock {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(receipt).write(to: fileURL, options: [.atomic])
        }
    }

    public static func defaultStoreURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("ShareSync", isDirectory: true)
            .appendingPathComponent("note-sync-receipt-v1.json", isDirectory: false)
    }
}

private extension NSLock {
    func withReceiptLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
