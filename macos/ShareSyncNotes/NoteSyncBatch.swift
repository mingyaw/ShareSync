import Foundation

public enum NoteSyncBatchError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case blankBatchID
    case blankSourceDeviceID
    case invalidGenerationTime
    case duplicateNoteID(String)
}

public struct NoteSyncBatch: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let batchId: String
    public let sourceDeviceId: String
    public let generatedAtEpochMillis: Int64
    public let notes: [VersionedNote]

    public init(
        schemaVersion: Int = NoteSyncBatch.currentSchemaVersion,
        batchId: String,
        sourceDeviceId: String,
        generatedAtEpochMillis: Int64,
        notes: [VersionedNote]
    ) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw NoteSyncBatchError.unsupportedSchemaVersion(schemaVersion)
        }
        guard !batchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NoteSyncBatchError.blankBatchID
        }
        guard !sourceDeviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NoteSyncBatchError.blankSourceDeviceID
        }
        guard generatedAtEpochMillis >= 0 else {
            throw NoteSyncBatchError.invalidGenerationTime
        }
        var seen = Set<String>()
        for note in notes where !seen.insert(note.id).inserted {
            throw NoteSyncBatchError.duplicateNoteID(note.id)
        }
        self.schemaVersion = schemaVersion
        self.batchId = batchId
        self.sourceDeviceId = sourceDeviceId
        self.generatedAtEpochMillis = generatedAtEpochMillis
        self.notes = notes.sorted { $0.id < $1.id }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, batchId, sourceDeviceId, generatedAtEpochMillis, notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            batchId: container.decode(String.self, forKey: .batchId),
            sourceDeviceId: container.decode(String.self, forKey: .sourceDeviceId),
            generatedAtEpochMillis: container.decode(Int64.self, forKey: .generatedAtEpochMillis),
            notes: container.decode([VersionedNote].self, forKey: .notes)
        )
    }
}

public struct NoteSyncBatchCodec: Sendable {
    public init() {}

    public func encode(_ batch: NoteSyncBatch) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(batch)
    }

    public func decode(_ data: Data) throws -> NoteSyncBatch {
        try JSONDecoder().decode(NoteSyncBatch.self, from: data)
    }
}
