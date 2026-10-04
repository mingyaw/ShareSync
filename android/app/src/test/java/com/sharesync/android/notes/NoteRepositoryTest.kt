package com.sharesync.android.notes

import com.sharesync.android.SuspendBridge
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class NoteRepositoryTest {
    @Test
    fun sharedFixtureUsesTheSameKotlinAndSwiftJsonContract() {
        val fixture = sharedFixture("sample-note-store.json")
        val codec = NoteJsonCodec()

        val notes = codec.decode(fixture.readText())
        val roundTripped = codec.decode(codec.encode(notes))

        assertEquals(1, notes.size)
        assertEquals("3c348be6-01af-4d16-93cf-ddb1d27de133", notes.single().id)
        assertEquals(NoteRevision(2, "android-primary"), notes.single().revision)
        assertEquals(NoteRevision(1, "android-primary"), notes.single().parentRevision)
        assertEquals(notes, roundTripped)
    }

    @Test
    fun sharedSyncBatchFixtureUsesTheSameKotlinAndSwiftContract() {
        val fixture = sharedFixture("sample-note-sync-batch.json")
        val codec = NoteSyncBatchCodec()

        val batch = codec.decode(fixture.readText())
        val roundTripped = codec.decode(codec.encode(batch))

        assertEquals("notes-20261004-001", batch.batchId)
        assertEquals("android-primary", batch.sourceDeviceId)
        assertEquals(1, batch.notes.size)
        assertEquals(batch, roundTripped)
    }

    @Test(expected = IllegalArgumentException::class)
    fun syncBatchRejectsDuplicateNoteIds() {
        val note = note(revision = NoteRevision(1, "android-primary"))
        NoteSyncBatch(
            batchId = "duplicate",
            sourceDeviceId = "android-primary",
            generatedAtEpochMillis = 1,
            notes = listOf(note, note),
        )
    }

    @Test
    fun localMutationsCreateRevisionLineageAndTombstone() {
        val store = InMemoryNoteStore()
        var timestamp = 1_000L
        val repository = NoteRepository(
            store = store,
            deviceId = "android-primary",
            now = { timestamp++ },
            newId = { "note-001" },
        )

        val created = SuspendBridge.runBlocking {
            repository.create("Trip", "Pack **light**", listOf(" Travel ", "travel", "Taiwan"))
        }
        val updated = SuspendBridge.runBlocking {
            repository.update(created.id, created.revision, "Trip plan", "Pack light", listOf("Taiwan"))
        }
        val deleted = SuspendBridge.runBlocking {
            repository.delete(updated.id, updated.revision)
        }

        assertEquals(NoteRevision(1, "android-primary"), created.revision)
        assertEquals(listOf("Taiwan", "Travel"), created.tags)
        assertEquals(created.revision, updated.parentRevision)
        assertEquals(NoteRevision(2, "android-primary"), updated.revision)
        assertEquals(updated.revision, deleted.parentRevision)
        assertEquals(NoteRevision(3, "android-primary"), deleted.revision)
        assertTrue(deleted.isDeleted)
        assertEquals("", deleted.title)
        assertEquals("", deleted.markdownBody)
        assertTrue(deleted.tags.isEmpty())
    }

    @Test(expected = IllegalArgumentException::class)
    fun staleLocalEditIsRejected() {
        val repository = NoteRepository(
            store = InMemoryNoteStore(),
            deviceId = "android-primary",
            now = { 1_000L },
            newId = { "note-001" },
        )
        val created = SuspendBridge.runBlocking { repository.create("Title", "Body") }
        SuspendBridge.runBlocking {
            repository.update(created.id, created.revision, "First", "Body", emptyList())
            repository.update(created.id, created.revision, "Stale", "Body", emptyList())
        }
    }

    @Test
    fun fileStorePersistsAllVersionFieldsAcrossReload() {
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncNoteStore-${System.nanoTime()}")
        val file = File(directory, "notes-v1.json")
        val note = note(
            revision = NoteRevision(4, "android-primary"),
            parent = NoteRevision(3, "mac-studio"),
            deletedAt = 2_000L,
            conflictOf = "note-original",
        )

        try {
            SuspendBridge.runBlocking { FileNoteStore(file).replace(listOf(note)) }
            val restored = SuspendBridge.runBlocking { FileNoteStore(file).get(note.id) }

            assertEquals(note, restored)
            assertTrue(file.readText().contains("\"schemaVersion\": 1"))
        } finally {
            file.delete()
            File(directory, "notes-v1.json.tmp").delete()
            directory.delete()
        }
    }

    @Test
    fun directDescendantFastForwardsWithoutConflict() {
        val local = note(revision = NoteRevision(1, "android-primary"))
        val remote = local.copy(
            title = "Edited on Mac",
            revision = NoteRevision(2, "mac-studio"),
            parentRevision = local.revision,
        )

        val result = NoteMergePolicy().merge(local, remote)

        assertEquals(NoteMergeStatus.acceptedRemote, result.status)
        assertEquals(remote, result.primary)
        assertNull(result.conflictCopy)
    }

    @Test
    fun concurrentEditsProduceStableVisibleConflictCopy() {
        val base = note(revision = NoteRevision(1, "android-primary"))
        val android = base.copy(
            title = "Android edit",
            revision = NoteRevision(2, "android-primary"),
            parentRevision = base.revision,
        )
        val mac = base.copy(
            title = "Mac edit",
            revision = NoteRevision(2, "mac-studio"),
            parentRevision = base.revision,
        )
        val policy = NoteMergePolicy()

        val first = policy.merge(android, mac)
        val reversed = policy.merge(mac, android)

        assertEquals(NoteMergeStatus.conflict, first.status)
        assertEquals(mac, first.primary)
        assertEquals(first.primary, reversed.primary)
        assertEquals(first.conflictCopy, reversed.conflictCopy)
        assertEquals("5fb363eb-e718-3aef-9c23-9ab0e9c3b6e0", first.conflictCopy?.id)
        assertEquals("note-001", first.conflictCopy?.conflictOfNoteId)
        assertTrue(first.conflictCopy?.title?.startsWith("[Conflict - android-primary]") == true)
        assertFalse(first.conflictCopy?.isDeleted ?: true)
    }

    @Test
    fun concurrentDeleteWinsAndPreservesEditAsConflictCopy() {
        val base = note(revision = NoteRevision(1, "android-primary"))
        val edit = base.copy(
            title = "Offline edit",
            revision = NoteRevision(2, "android-primary"),
            parentRevision = base.revision,
        )
        val tombstone = base.copy(
            title = "",
            markdownBody = "",
            tags = emptyList(),
            updatedAtEpochMillis = 2_000L,
            revision = NoteRevision(2, "mac-studio"),
            parentRevision = base.revision,
            deletedAtEpochMillis = 2_000L,
        )

        val result = NoteMergePolicy().merge(edit, tombstone)

        assertEquals(tombstone, result.primary)
        assertTrue(result.primary.isDeleted)
        assertEquals("Offline edit", result.conflictCopy?.title?.substringAfter("] "))
        assertFalse(result.conflictCopy?.isDeleted ?: true)
    }

    @Test
    fun retryingConcurrentMergeDoesNotDuplicateConflictCopy() {
        val store = InMemoryNoteStore()
        val base = note(revision = NoteRevision(1, "android-primary"))
        val local = base.copy(
            title = "Android edit",
            revision = NoteRevision(2, "android-primary"),
            parentRevision = base.revision,
        )
        val remote = base.copy(
            title = "Mac edit",
            revision = NoteRevision(2, "mac-studio"),
            parentRevision = base.revision,
        )
        SuspendBridge.runBlocking { store.replace(listOf(local)) }
        val repository = NoteRepository(store, "android-primary")

        val first = SuspendBridge.runBlocking { repository.mergeRemote(remote) }
        val second = SuspendBridge.runBlocking { repository.mergeRemote(remote) }
        val persisted = SuspendBridge.runBlocking { store.all() }

        assertEquals(NoteMergeStatus.unchanged, second.status)
        assertTrue(first.conflictCopy?.id in persisted.map(VersionedNote::id))
        assertEquals(2, persisted.size)
        assertEquals(2, persisted.map(VersionedNote::id).distinct().size)
    }

    @Test
    fun newRemoteNoteIsPersistedWithoutConflict() {
        val store = InMemoryNoteStore()
        val repository = NoteRepository(store, "android-primary")
        val remote = note(revision = NoteRevision(1, "mac-studio"))

        val result = SuspendBridge.runBlocking { repository.mergeRemote(remote) }

        assertEquals(NoteMergeStatus.acceptedRemote, result.status)
        assertEquals(remote, SuspendBridge.runBlocking { store.get(remote.id) })
        assertNull(result.conflictCopy)
    }

    @Test
    fun batchMergeReportsDeterministicAggregateResult() {
        val base = note(revision = NoteRevision(1, "android-primary"))
        val descendant = base.copy(
            title = "Mac update",
            revision = NoteRevision(2, "mac-studio"),
            parentRevision = base.revision,
        )
        val newNote = base.copy(id = "note-002")
        val store = InMemoryNoteStore(listOf(base))
        val repository = NoteRepository(store, "android-primary")
        val batch = NoteSyncBatch(
            batchId = "batch-001",
            sourceDeviceId = "mac-studio",
            generatedAtEpochMillis = 2_000,
            notes = listOf(newNote, descendant),
        )

        val result = SuspendBridge.runBlocking { repository.mergeRemoteBatch(batch) }

        assertEquals(2, result.acceptedRemoteCount)
        assertEquals(0, result.keptLocalCount)
        assertEquals(0, result.unchangedCount)
        assertEquals(0, result.conflictCount)
        assertEquals(0, result.conflictCopyCount)
        assertEquals(listOf("note-001", "note-002"), SuspendBridge.runBlocking { store.all() }.map { it.id })
    }

    private fun note(
        revision: NoteRevision,
        parent: NoteRevision? = null,
        deletedAt: Long? = null,
        conflictOf: String? = null,
    ): VersionedNote {
        return VersionedNote(
            id = "note-001",
            title = if (deletedAt == null) "Title" else "",
            markdownBody = if (deletedAt == null) "Markdown body" else "",
            createdAtEpochMillis = 1_000L,
            updatedAtEpochMillis = if (deletedAt == null) 1_500L else deletedAt,
            tags = if (deletedAt == null) listOf("personal") else emptyList(),
            revision = revision,
            parentRevision = parent,
            deletedAtEpochMillis = deletedAt,
            conflictOfNoteId = conflictOf,
        )
    }

    private fun sharedFixture(name: String): File {
        val workingDirectory = File(".").canonicalFile
        return generateSequence(workingDirectory) { it.parentFile }
            .map { File(it, "shared/fixtures/$name") }
            .firstOrNull(File::isFile)
            ?: error("Shared fixture not found: $name (working directory ${File(".").absolutePath})")
    }
}
