import Foundation

public enum NoteStoreError: Error, Equatable {
    case duplicateNoteID(String)
    case noteNotFound(String)
    case staleRevision
    case deletedNoteCannotBeEdited
}

public protocol NoteStore: AnyObject {
    func all() throws -> [VersionedNote]
    func note(id: String) throws -> VersionedNote?
    func replace(with notes: [VersionedNote]) throws
}

public final class InMemoryNoteStore: NoteStore {
    private let lock = NSLock()
    private var notesByID: [String: VersionedNote]

    public init(initialNotes: [VersionedNote] = []) {
        notesByID = Dictionary(uniqueKeysWithValues: initialNotes.map { ($0.id, $0) })
    }

    public func all() -> [VersionedNote] {
        lock.withLock { notesByID.values.sorted { $0.id < $1.id } }
    }

    public func note(id: String) -> VersionedNote? {
        lock.withLock { notesByID[id] }
    }

    public func replace(with notes: [VersionedNote]) throws {
        let updated = try Self.index(notes)
        lock.withLock { notesByID = updated }
    }

    private static func index(_ notes: [VersionedNote]) throws -> [String: VersionedNote] {
        var result: [String: VersionedNote] = [:]
        for note in notes {
            guard result.updateValue(note, forKey: note.id) == nil else {
                throw NoteStoreError.duplicateNoteID(note.id)
            }
        }
        return result
    }
}

public final class FileNoteStore: NoteStore {
    private let fileManager: FileManager
    public let fileURL: URL
    private let codec: NoteJSONCodec
    private let lock = NSLock()

    public init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil,
        codec: NoteJSONCodec = NoteJSONCodec()
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultStoreURL(fileManager: fileManager)
        self.codec = codec
    }

    public func all() throws -> [VersionedNote] {
        try lock.withLock { try readNotes() }
    }

    public func note(id: String) throws -> VersionedNote? {
        try lock.withLock { try readNotes().first { $0.id == id } }
    }

    public func replace(with notes: [VersionedNote]) throws {
        try lock.withLock {
            var seen = Set<String>()
            for note in notes where !seen.insert(note.id).inserted {
                throw NoteStoreError.duplicateNoteID(note.id)
            }
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try codec.encode(notes.sorted { $0.id < $1.id })
            try data.write(to: fileURL, options: [.atomic])
        }
    }

    private func readNotes() throws -> [VersionedNote] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        return try codec.decode(Data(contentsOf: fileURL))
    }

    public static func defaultStoreURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base
            .appendingPathComponent("ShareSync", isDirectory: true)
            .appendingPathComponent("notes-v1.json", isDirectory: false)
    }
}

public enum MacNoteDeviceIdentity {
    private static let key = "sharesync.mac.note-device-id"

    public static func persistentID(defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: key),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }
        let value = "mac-\(UUID().uuidString.lowercased())"
        defaults.set(value, forKey: key)
        return value
    }
}

public final class NoteRepository {
    private let store: NoteStore
    private let deviceID: String
    private let now: () -> Int64
    private let newID: () -> String
    private let mergePolicy: NoteMergePolicy

    public init(
        store: NoteStore,
        deviceID: String,
        now: @escaping () -> Int64 = {
            Int64((Date().timeIntervalSince1970 * 1_000).rounded(.down))
        },
        newID: @escaping () -> String = { UUID().uuidString.lowercased() },
        mergePolicy: NoteMergePolicy = NoteMergePolicy()
    ) throws {
        guard !deviceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NoteModelError.blankDeviceID
        }
        self.store = store
        self.deviceID = deviceID
        self.now = now
        self.newID = newID
        self.mergePolicy = mergePolicy
    }

    @discardableResult
    public func create(title: String, markdownBody: String, tags: [String] = []) throws -> VersionedNote {
        let timestamp = now()
        let note = try VersionedNote(
            id: newID(),
            title: title,
            markdownBody: markdownBody,
            createdAtEpochMillis: timestamp,
            updatedAtEpochMillis: timestamp,
            tags: tags,
            revision: NoteRevision(sequence: 1, deviceId: deviceID),
            parentRevision: nil,
            deletedAtEpochMillis: nil
        )
        try put(note)
        return note
    }

    @discardableResult
    public func update(
        id: String,
        expectedRevision: NoteRevision,
        title: String,
        markdownBody: String,
        tags: [String]
    ) throws -> VersionedNote {
        let current = try requireCurrent(id: id, expectedRevision: expectedRevision)
        guard !current.isDeleted else { throw NoteStoreError.deletedNoteCannotBeEdited }
        let updated = try current.replacing(
            title: title,
            markdownBody: markdownBody,
            updatedAtEpochMillis: max(now(), current.updatedAtEpochMillis),
            tags: tags,
            revision: NoteRevision(sequence: current.revision.sequence + 1, deviceId: deviceID),
            parentRevision: .some(current.revision)
        )
        try put(updated)
        return updated
    }

    @discardableResult
    public func delete(id: String, expectedRevision: NoteRevision) throws -> VersionedNote {
        let current = try requireCurrent(id: id, expectedRevision: expectedRevision)
        if current.isDeleted { return current }
        let timestamp = max(now(), current.updatedAtEpochMillis)
        let tombstone = try current.replacing(
            title: "",
            markdownBody: "",
            updatedAtEpochMillis: timestamp,
            tags: [],
            revision: NoteRevision(sequence: current.revision.sequence + 1, deviceId: deviceID),
            parentRevision: .some(current.revision),
            deletedAtEpochMillis: .some(timestamp)
        )
        try put(tombstone)
        return tombstone
    }

    @discardableResult
    public func mergeRemote(_ remote: VersionedNote) throws -> NoteMergeResult {
        guard let local = try store.note(id: remote.id) else {
            try put(remote)
            return NoteMergeResult(status: .acceptedRemote, primary: remote)
        }
        let result = try mergePolicy.merge(local: local, remote: remote)
        var notes = Dictionary(uniqueKeysWithValues: try store.all().map { ($0.id, $0) })
        notes[result.primary.id] = result.primary
        if let conflictCopy = result.conflictCopy { notes[conflictCopy.id] = conflictCopy }
        try store.replace(with: Array(notes.values))
        return result
    }

    public func mergeRemoteBatch(_ batch: NoteSyncBatch) throws -> NoteMergeBatchResult {
        var counts: [NoteMergeStatus: Int] = [:]
        var conflictCopyCount = 0
        for note in batch.notes.sorted(by: {
            $0.id == $1.id ? $0.revision < $1.revision : $0.id < $1.id
        }) {
            let result = try mergeRemote(note)
            counts[result.status, default: 0] += 1
            if result.conflictCopy != nil { conflictCopyCount += 1 }
        }
        return NoteMergeBatchResult(
            acceptedRemoteCount: counts[.acceptedRemote, default: 0],
            keptLocalCount: counts[.keptLocal, default: 0],
            unchangedCount: counts[.unchanged, default: 0],
            conflictCount: counts[.conflict, default: 0],
            conflictCopyCount: conflictCopyCount
        )
    }

    public func allNotes(includeDeleted: Bool = false) throws -> [VersionedNote] {
        let notes = try store.all()
        return includeDeleted ? notes : notes.filter { !$0.isDeleted }
    }

    public func createSyncBatch(
        batchID: String,
        generatedAtEpochMillis: Int64? = nil
    ) throws -> NoteSyncBatch {
        try NoteSyncBatch(
            batchId: batchID,
            sourceDeviceId: deviceID,
            generatedAtEpochMillis: generatedAtEpochMillis ?? now(),
            notes: store.all()
        )
    }

    private func requireCurrent(id: String, expectedRevision: NoteRevision) throws -> VersionedNote {
        guard let current = try store.note(id: id) else { throw NoteStoreError.noteNotFound(id) }
        guard current.revision == expectedRevision else { throw NoteStoreError.staleRevision }
        return current
    }

    private func put(_ note: VersionedNote) throws {
        var notes = Dictionary(uniqueKeysWithValues: try store.all().map { ($0.id, $0) })
        notes[note.id] = note
        try store.replace(with: Array(notes.values))
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
