import Foundation

public enum NoteJSONCodecError: Error, Equatable {
    case unsupportedStoreSchemaVersion(Int)
}

private struct NoteStoreEnvelope: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let notes: [VersionedNote]

    init(notes: [VersionedNote]) {
        schemaVersion = Self.currentSchemaVersion
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw NoteJSONCodecError.unsupportedStoreSchemaVersion(schemaVersion)
        }
        self.schemaVersion = schemaVersion
        notes = try container.decode([VersionedNote].self, forKey: .notes)
    }
}

public struct NoteJSONCodec: Sendable {
    public init() {}

    public func encode(_ notes: [VersionedNote]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(NoteStoreEnvelope(notes: notes))
    }

    public func decode(_ data: Data) throws -> [VersionedNote] {
        try JSONDecoder().decode(NoteStoreEnvelope.self, from: data).notes
    }
}
