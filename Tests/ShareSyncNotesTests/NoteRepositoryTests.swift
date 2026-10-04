import Foundation
import XCTest
@testable import ShareSyncNotes

final class NoteRepositoryTests: XCTestCase {
    func testAllNotesHidesTombstonesByDefault() throws {
        let store = InMemoryNoteStore()
        let repository = try NoteRepository(
            store: store,
            deviceID: "mac-studio",
            now: { 1_000 },
            newID: { "note-001" }
        )
        let note = try repository.create(title: "Private", markdownBody: "Body")
        _ = try repository.delete(id: note.id, expectedRevision: note.revision)

        XCTAssertTrue(try repository.allNotes().isEmpty)
        XCTAssertEqual(try repository.allNotes(includeDeleted: true).map(\.id), ["note-001"])
    }

    func testLocalMutationsCreateRevisionLineageAndTombstone() throws {
        let store = InMemoryNoteStore()
        var timestamp: Int64 = 1_000
        let repository = try NoteRepository(
            store: store,
            deviceID: "mac-studio",
            now: { defer { timestamp += 1 }; return timestamp },
            newID: { "note-001" }
        )

        let created = try repository.create(
            title: "Trip",
            markdownBody: "Pack **light**",
            tags: [" Travel ", "travel", "Taiwan"]
        )
        let updated = try repository.update(
            id: created.id,
            expectedRevision: created.revision,
            title: "Trip plan",
            markdownBody: "Pack light",
            tags: ["Taiwan"]
        )
        let deleted = try repository.delete(id: updated.id, expectedRevision: updated.revision)

        XCTAssertEqual(created.revision, try NoteRevision(sequence: 1, deviceId: "mac-studio"))
        XCTAssertEqual(created.tags, ["Taiwan", "Travel"])
        XCTAssertEqual(updated.parentRevision, created.revision)
        XCTAssertEqual(updated.revision, try NoteRevision(sequence: 2, deviceId: "mac-studio"))
        XCTAssertEqual(deleted.parentRevision, updated.revision)
        XCTAssertEqual(deleted.revision, try NoteRevision(sequence: 3, deviceId: "mac-studio"))
        XCTAssertTrue(deleted.isDeleted)
        XCTAssertEqual(deleted.title, "")
        XCTAssertEqual(deleted.markdownBody, "")
        XCTAssertEqual(deleted.tags, [])
    }

    func testStaleEditIsRejected() throws {
        let repository = try NoteRepository(
            store: InMemoryNoteStore(),
            deviceID: "mac-studio",
            now: { 1_000 },
            newID: { "note-001" }
        )
        let created = try repository.create(title: "Title", markdownBody: "Body")
        _ = try repository.update(
            id: created.id,
            expectedRevision: created.revision,
            title: "First",
            markdownBody: "Body",
            tags: []
        )

        XCTAssertThrowsError(try repository.update(
            id: created.id,
            expectedRevision: created.revision,
            title: "Stale",
            markdownBody: "Body",
            tags: []
        )) {
            XCTAssertEqual($0 as? NoteStoreError, .staleRevision)
        }
    }

    func testFileStoreAtomicallyPersistsAllVersionFields() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncNotesTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("notes-v1.json")
        let note = try makeNote(
            revision: NoteRevision(sequence: 4, deviceId: "mac-studio"),
            parent: NoteRevision(sequence: 3, deviceId: "android-primary"),
            deletedAt: 2_000,
            conflictOf: "note-original"
        )

        try FileNoteStore(fileURL: fileURL).replace(with: [note])
        let restored = try FileNoteStore(fileURL: fileURL).note(id: note.id)

        XCTAssertEqual(restored, note)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path + ".tmp"))
    }

    func testDirectDescendantFastForwardsWithoutConflict() throws {
        let local = try makeNote(revision: NoteRevision(sequence: 1, deviceId: "android-primary"))
        let remote = try local.replacing(
            title: "Edited on Mac",
            revision: NoteRevision(sequence: 2, deviceId: "mac-studio"),
            parentRevision: .some(local.revision)
        )

        let result = try NoteMergePolicy().merge(local: local, remote: remote)

        XCTAssertEqual(result.status, .acceptedRemote)
        XCTAssertEqual(result.primary, remote)
        XCTAssertNil(result.conflictCopy)
    }

    func testConcurrentEditsProduceJavaCompatibleStableConflictCopy() throws {
        let base = try makeNote(revision: NoteRevision(sequence: 1, deviceId: "android-primary"))
        let android = try base.replacing(
            title: "Android edit",
            revision: NoteRevision(sequence: 2, deviceId: "android-primary"),
            parentRevision: .some(base.revision)
        )
        let mac = try base.replacing(
            title: "Mac edit",
            revision: NoteRevision(sequence: 2, deviceId: "mac-studio"),
            parentRevision: .some(base.revision)
        )
        let policy = NoteMergePolicy()

        let first = try policy.merge(local: android, remote: mac)
        let reversed = try policy.merge(local: mac, remote: android)

        XCTAssertEqual(first.status, .conflict)
        XCTAssertEqual(first.primary, mac)
        XCTAssertEqual(first.primary, reversed.primary)
        XCTAssertEqual(first.conflictCopy, reversed.conflictCopy)
        XCTAssertEqual(first.conflictCopy?.id, "5fb363eb-e718-3aef-9c23-9ab0e9c3b6e0")
        XCTAssertEqual(first.conflictCopy?.conflictOfNoteId, "note-001")
        XCTAssertEqual(first.conflictCopy?.title, "[Conflict - android-primary] Android edit")
        XCTAssertFalse(first.conflictCopy?.isDeleted ?? true)
    }

    func testConcurrentDeleteWinsAndPreservesEdit() throws {
        let base = try makeNote(revision: NoteRevision(sequence: 1, deviceId: "android-primary"))
        let edit = try base.replacing(
            title: "Offline edit",
            revision: NoteRevision(sequence: 2, deviceId: "android-primary"),
            parentRevision: .some(base.revision)
        )
        let tombstone = try base.replacing(
            title: "",
            markdownBody: "",
            updatedAtEpochMillis: 2_000,
            tags: [],
            revision: NoteRevision(sequence: 2, deviceId: "mac-studio"),
            parentRevision: .some(base.revision),
            deletedAtEpochMillis: .some(2_000)
        )

        let result = try NoteMergePolicy().merge(local: edit, remote: tombstone)

        XCTAssertEqual(result.primary, tombstone)
        XCTAssertTrue(result.primary.isDeleted)
        XCTAssertEqual(result.conflictCopy?.title, "[Conflict - android-primary] Offline edit")
        XCTAssertFalse(result.conflictCopy?.isDeleted ?? true)
    }

    func testRetryingConcurrentMergeDoesNotDuplicateConflictCopy() throws {
        let base = try makeNote(revision: NoteRevision(sequence: 1, deviceId: "android-primary"))
        let local = try base.replacing(
            title: "Android edit",
            revision: NoteRevision(sequence: 2, deviceId: "android-primary"),
            parentRevision: .some(base.revision)
        )
        let remote = try base.replacing(
            title: "Mac edit",
            revision: NoteRevision(sequence: 2, deviceId: "mac-studio"),
            parentRevision: .some(base.revision)
        )
        let store = InMemoryNoteStore(initialNotes: [local])
        let repository = try NoteRepository(store: store, deviceID: "mac-studio")

        let first = try repository.mergeRemote(remote)
        let second = try repository.mergeRemote(remote)

        XCTAssertEqual(second.status, .unchanged)
        XCTAssertTrue(store.all().contains { $0.id == first.conflictCopy?.id })
        XCTAssertEqual(store.all().count, 2)
    }

    func testDeviceIdentityIsDurableAndMacScoped() throws {
        let suite = "ShareSyncNotesTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = MacNoteDeviceIdentity.persistentID(defaults: defaults)
        let second = MacNoteDeviceIdentity.persistentID(defaults: defaults)

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.hasPrefix("mac-"))
    }

    func testBatchMergeReportsDeterministicAggregateResult() throws {
        let base = try makeNote(revision: NoteRevision(sequence: 1, deviceId: "android-primary"))
        let descendant = try base.replacing(
            title: "Mac update",
            revision: NoteRevision(sequence: 2, deviceId: "mac-studio"),
            parentRevision: .some(base.revision)
        )
        let newNote = try base.replacing(
            id: "note-002",
            revision: NoteRevision(sequence: 1, deviceId: "android-primary")
        )
        let store = InMemoryNoteStore(initialNotes: [base])
        let repository = try NoteRepository(store: store, deviceID: "mac-studio")
        let batch = try NoteSyncBatch(
            batchId: "batch-001",
            sourceDeviceId: "android-primary",
            generatedAtEpochMillis: 2_000,
            notes: [newNote, descendant]
        )

        let result = try repository.mergeRemoteBatch(batch)

        XCTAssertEqual(result.acceptedRemoteCount, 2)
        XCTAssertEqual(result.keptLocalCount, 0)
        XCTAssertEqual(result.unchangedCount, 0)
        XCTAssertEqual(result.conflictCount, 0)
        XCTAssertEqual(result.conflictCopyCount, 0)
        XCTAssertEqual(store.all().map(\.id), ["note-001", "note-002"])
    }

    private func makeNote(
        revision: NoteRevision,
        parent: NoteRevision? = nil,
        deletedAt: Int64? = nil,
        conflictOf: String? = nil
    ) throws -> VersionedNote {
        try VersionedNote(
            id: "note-001",
            title: deletedAt == nil ? "Title" : "",
            markdownBody: deletedAt == nil ? "Markdown body" : "",
            createdAtEpochMillis: 1_000,
            updatedAtEpochMillis: deletedAt ?? 1_500,
            tags: deletedAt == nil ? ["personal"] : [],
            revision: revision,
            parentRevision: parent,
            deletedAtEpochMillis: deletedAt,
            conflictOfNoteId: conflictOf
        )
    }
}
