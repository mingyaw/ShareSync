import CryptoKit
import Foundation

public enum NoteMergeStatus: Hashable, Sendable {
    case unchanged
    case acceptedRemote
    case keptLocal
    case conflict
}

public struct NoteMergeResult: Equatable, Sendable {
    public let status: NoteMergeStatus
    public let primary: VersionedNote
    public let conflictCopy: VersionedNote?

    public init(status: NoteMergeStatus, primary: VersionedNote, conflictCopy: VersionedNote? = nil) {
        self.status = status
        self.primary = primary
        self.conflictCopy = conflictCopy
    }
}

public struct NoteMergeBatchResult: Equatable, Sendable {
    public let acceptedRemoteCount: Int
    public let keptLocalCount: Int
    public let unchangedCount: Int
    public let conflictCount: Int
    public let conflictCopyCount: Int
}

public enum NoteMergeError: Error, Equatable {
    case differentNoteIDs
    case inconsistentRevisionStamp
}

public struct NoteMergePolicy: Sendable {
    public init() {}

    public func merge(local: VersionedNote, remote: VersionedNote) throws -> NoteMergeResult {
        guard local.id == remote.id else { throw NoteMergeError.differentNoteIDs }
        if local == remote {
            return NoteMergeResult(status: .unchanged, primary: local)
        }
        if remote.parentRevision == local.revision {
            return NoteMergeResult(status: .acceptedRemote, primary: remote)
        }
        if local.parentRevision == remote.revision {
            return NoteMergeResult(status: .keptLocal, primary: local)
        }
        guard local.revision != remote.revision else {
            throw NoteMergeError.inconsistentRevisionStamp
        }

        let primary = choosePrimary(local, remote)
        let loser = primary == local ? remote : local
        if primary.isDeleted && loser.isDeleted {
            return NoteMergeResult(status: .conflict, primary: primary)
        }

        return NoteMergeResult(
            status: .conflict,
            primary: primary,
            conflictCopy: try conflictCopy(originalID: local.id, loser: loser, other: primary)
        )
    }

    private func choosePrimary(_ local: VersionedNote, _ remote: VersionedNote) -> VersionedNote {
        if local.isDeleted != remote.isDeleted {
            return local.isDeleted ? local : remote
        }
        return local.revision >= remote.revision ? local : remote
    }

    private func conflictCopy(
        originalID: String,
        loser: VersionedNote,
        other: VersionedNote
    ) throws -> VersionedNote {
        let pairKey = [revisionKey(loser.revision), revisionKey(other.revision)].sorted().joined(separator: "|")
        let name = "sharesync-note-conflict|\(originalID)|\(pairKey)"
        let conflictID = uuidV3Name(name)
        let source = loser.isDeleted ? other : loser
        return try source.replacing(
            id: conflictID,
            title: "[Conflict - \(source.revision.deviceId)] \(source.title)",
            deletedAtEpochMillis: .some(nil),
            conflictOfNoteId: .some(originalID)
        )
    }

    private func revisionKey(_ revision: NoteRevision) -> String {
        "\(revision.sequence)@\(revision.deviceId)"
    }

    // Matches java.util.UUID.nameUUIDFromBytes: MD5 the raw UTF-8 name, then set RFC 4122 v3 bits.
    private func uuidV3Name(_ name: String) -> String {
        var bytes = Array(Insecure.MD5.hash(data: Data(name.utf8)))
        bytes[6] = (bytes[6] & 0x0f) | 0x30
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }
        return [
            hex[0...3].joined(),
            hex[4...5].joined(),
            hex[6...7].joined(),
            hex[8...9].joined(),
            hex[10...15].joined(),
        ].joined(separator: "-")
    }
}
