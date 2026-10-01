import Foundation

public enum NoteModelError: Error, Equatable {
    case invalidRevisionSequence
    case blankDeviceID
    case unsupportedSchemaVersion(Int)
    case blankNoteID
    case invalidCreationTime
    case updatePrecedesCreation
    case deletionPrecedesUpdate
    case revisionIsOwnParent
    case conflictReferencesSelf
    case missingRequiredField(String)
}

public struct NoteRevision: Codable, Hashable, Comparable, Sendable {
    public let sequence: Int64
    public let deviceId: String

    public init(sequence: Int64, deviceId: String) throws {
        guard sequence > 0 else { throw NoteModelError.invalidRevisionSequence }
        guard !deviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NoteModelError.blankDeviceID
        }
        self.sequence = sequence
        self.deviceId = deviceId
    }

    public static func < (lhs: NoteRevision, rhs: NoteRevision) -> Bool {
        if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
        return lhs.deviceId < rhs.deviceId
    }

    private enum CodingKeys: String, CodingKey {
        case sequence
        case deviceId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            sequence: container.decode(Int64.self, forKey: .sequence),
            deviceId: container.decode(String.self, forKey: .deviceId)
        )
    }
}

public struct VersionedNote: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let id: String
    public let title: String
    public let markdownBody: String
    public let createdAtEpochMillis: Int64
    public let updatedAtEpochMillis: Int64
    public let tags: [String]
    public let revision: NoteRevision
    public let parentRevision: NoteRevision?
    public let deletedAtEpochMillis: Int64?
    public let conflictOfNoteId: String?

    public var isDeleted: Bool { deletedAtEpochMillis != nil }

    public init(
        schemaVersion: Int = VersionedNote.currentSchemaVersion,
        id: String,
        title: String,
        markdownBody: String,
        createdAtEpochMillis: Int64,
        updatedAtEpochMillis: Int64,
        tags: [String],
        revision: NoteRevision,
        parentRevision: NoteRevision?,
        deletedAtEpochMillis: Int64?,
        conflictOfNoteId: String? = nil
    ) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw NoteModelError.unsupportedSchemaVersion(schemaVersion)
        }
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NoteModelError.blankNoteID
        }
        guard createdAtEpochMillis >= 0 else { throw NoteModelError.invalidCreationTime }
        guard updatedAtEpochMillis >= createdAtEpochMillis else {
            throw NoteModelError.updatePrecedesCreation
        }
        guard deletedAtEpochMillis == nil || deletedAtEpochMillis! >= updatedAtEpochMillis else {
            throw NoteModelError.deletionPrecedesUpdate
        }
        guard parentRevision != revision else { throw NoteModelError.revisionIsOwnParent }
        guard conflictOfNoteId != id else { throw NoteModelError.conflictReferencesSelf }

        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.markdownBody = markdownBody
        self.createdAtEpochMillis = createdAtEpochMillis
        self.updatedAtEpochMillis = updatedAtEpochMillis
        self.tags = tags.normalizedNoteTags()
        self.revision = revision
        self.parentRevision = parentRevision
        self.deletedAtEpochMillis = deletedAtEpochMillis
        self.conflictOfNoteId = conflictOfNoteId
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case id
        case title
        case markdownBody
        case createdAtEpochMillis
        case updatedAtEpochMillis
        case tags
        case revision
        case parentRevision
        case deletedAtEpochMillis
        case conflictOfNoteId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        for key in CodingKeys.allCases where !container.contains(key) {
            throw NoteModelError.missingRequiredField(key.stringValue)
        }
        try self.init(
            schemaVersion: container.decode(Int.self, forKey: .schemaVersion),
            id: container.decode(String.self, forKey: .id),
            title: container.decode(String.self, forKey: .title),
            markdownBody: container.decode(String.self, forKey: .markdownBody),
            createdAtEpochMillis: container.decode(Int64.self, forKey: .createdAtEpochMillis),
            updatedAtEpochMillis: container.decode(Int64.self, forKey: .updatedAtEpochMillis),
            tags: container.decode([String].self, forKey: .tags),
            revision: container.decode(NoteRevision.self, forKey: .revision),
            parentRevision: container.decodeIfPresent(NoteRevision.self, forKey: .parentRevision),
            deletedAtEpochMillis: container.decodeIfPresent(Int64.self, forKey: .deletedAtEpochMillis),
            conflictOfNoteId: container.decodeIfPresent(String.self, forKey: .conflictOfNoteId)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(markdownBody, forKey: .markdownBody)
        try container.encode(createdAtEpochMillis, forKey: .createdAtEpochMillis)
        try container.encode(updatedAtEpochMillis, forKey: .updatedAtEpochMillis)
        try container.encode(tags, forKey: .tags)
        try container.encode(revision, forKey: .revision)
        try container.encode(parentRevision, forKey: .parentRevision)
        try container.encode(deletedAtEpochMillis, forKey: .deletedAtEpochMillis)
        try container.encode(conflictOfNoteId, forKey: .conflictOfNoteId)
    }

    func replacing(
        id: String? = nil,
        title: String? = nil,
        markdownBody: String? = nil,
        updatedAtEpochMillis: Int64? = nil,
        tags: [String]? = nil,
        revision: NoteRevision? = nil,
        parentRevision: NoteRevision?? = nil,
        deletedAtEpochMillis: Int64?? = nil,
        conflictOfNoteId: String?? = nil
    ) throws -> VersionedNote {
        try VersionedNote(
            schemaVersion: schemaVersion,
            id: id ?? self.id,
            title: title ?? self.title,
            markdownBody: markdownBody ?? self.markdownBody,
            createdAtEpochMillis: createdAtEpochMillis,
            updatedAtEpochMillis: updatedAtEpochMillis ?? self.updatedAtEpochMillis,
            tags: tags ?? self.tags,
            revision: revision ?? self.revision,
            parentRevision: parentRevision ?? self.parentRevision,
            deletedAtEpochMillis: deletedAtEpochMillis ?? self.deletedAtEpochMillis,
            conflictOfNoteId: conflictOfNoteId ?? self.conflictOfNoteId
        )
    }
}

public extension Array where Element == String {
    func normalizedNoteTags() -> [String] {
        var seen = Set<String>()
        return map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
            .sorted { $0.lowercased() < $1.lowercased() }
    }
}
