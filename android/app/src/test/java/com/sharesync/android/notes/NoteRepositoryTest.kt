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
}
