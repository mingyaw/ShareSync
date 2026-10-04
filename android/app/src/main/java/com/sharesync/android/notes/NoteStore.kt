package com.sharesync.android.notes

import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.UUID

interface NoteStore {
    suspend fun all(): List<VersionedNote>
    suspend fun get(id: String): VersionedNote?
    suspend fun replace(notes: List<VersionedNote>)
}

class InMemoryNoteStore(initialNotes: List<VersionedNote> = emptyList()) : NoteStore {
    private var notes = initialNotes.associateBy(VersionedNote::id)

    override suspend fun all(): List<VersionedNote> = notes.values.sortedBy(VersionedNote::id)

    override suspend fun get(id: String): VersionedNote? = notes[id]

    override suspend fun replace(notes: List<VersionedNote>) {
        this.notes = notes.associateBy(VersionedNote::id)
    }
}

class FileNoteStore(
    private val file: File,
    private val codec: NoteJsonCodec = NoteJsonCodec(),
) : NoteStore {
    private val lock = Any()

    override suspend fun all(): List<VersionedNote> = synchronized(lock) { readNotes() }

    override suspend fun get(id: String): VersionedNote? = synchronized(lock) {
        readNotes().firstOrNull { it.id == id }
    }

    override suspend fun replace(notes: List<VersionedNote>) = synchronized(lock) {
        require(notes.map(VersionedNote::id).distinct().size == notes.size) { "Duplicate note IDs are not allowed" }
        file.parentFile?.mkdirs()
        val temporary = File(file.parentFile, "${file.name}.tmp")
        temporary.writeText(codec.encode(notes.sortedBy(VersionedNote::id)))
        try {
            Files.move(
                temporary.toPath(),
                file.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
                StandardCopyOption.ATOMIC_MOVE,
            )
        } catch (_: Exception) {
            Files.move(temporary.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
        Unit
    }

    private fun readNotes(): List<VersionedNote> {
        if (!file.exists()) return emptyList()
        return codec.decode(file.readText())
    }

    companion object {
        fun defaultFile(filesDir: File): File = File(File(filesDir, "ShareSync"), "notes-v1.json")
    }
}

class NoteRepository(
    private val store: NoteStore,
    private val deviceId: String,
    private val now: () -> Long = System::currentTimeMillis,
    private val newId: () -> String = { UUID.randomUUID().toString() },
    private val mergePolicy: NoteMergePolicy = NoteMergePolicy(),
) {
    init {
        require(deviceId.isNotBlank()) { "Device ID must not be blank" }
    }

    suspend fun create(title: String, markdownBody: String, tags: List<String> = emptyList()): VersionedNote {
        val timestamp = now()
        val note = VersionedNote(
            id = newId(),
            title = title,
            markdownBody = markdownBody,
            createdAtEpochMillis = timestamp,
            updatedAtEpochMillis = timestamp,
            tags = tags.normalizedNoteTags(),
            revision = NoteRevision(1, deviceId),
            parentRevision = null,
            deletedAtEpochMillis = null,
        )
        put(note)
        return note
    }

    suspend fun update(
        id: String,
        expectedRevision: NoteRevision,
        title: String,
        markdownBody: String,
        tags: List<String>,
    ): VersionedNote {
        val current = requireCurrent(id, expectedRevision)
        require(!current.isDeleted) { "Deleted notes cannot be edited" }
        val updated = current.copy(
            title = title,
            markdownBody = markdownBody,
            updatedAtEpochMillis = now().coerceAtLeast(current.updatedAtEpochMillis),
            tags = tags.normalizedNoteTags(),
            revision = NoteRevision(current.revision.sequence + 1, deviceId),
            parentRevision = current.revision,
        )
        put(updated)
        return updated
    }

    suspend fun delete(id: String, expectedRevision: NoteRevision): VersionedNote {
        val current = requireCurrent(id, expectedRevision)
        if (current.isDeleted) return current
        val timestamp = now().coerceAtLeast(current.updatedAtEpochMillis)
        val tombstone = current.copy(
            title = "",
            markdownBody = "",
            tags = emptyList(),
            updatedAtEpochMillis = timestamp,
            revision = NoteRevision(current.revision.sequence + 1, deviceId),
            parentRevision = current.revision,
            deletedAtEpochMillis = timestamp,
        )
        put(tombstone)
        return tombstone
    }

    suspend fun mergeRemote(remote: VersionedNote): NoteMergeResult {
        val local = store.get(remote.id)
        if (local == null) {
            put(remote)
            return NoteMergeResult(NoteMergeStatus.acceptedRemote, remote)
        }
        val result = mergePolicy.merge(local, remote)
        val notes = store.all().associateBy(VersionedNote::id).toMutableMap()
        notes[result.primary.id] = result.primary
        result.conflictCopy?.let { notes[it.id] = it }
        store.replace(notes.values.toList())
        return result
    }

    suspend fun mergeRemoteBatch(batch: NoteSyncBatch): NoteMergeBatchResult {
        var acceptedRemoteCount = 0
        var keptLocalCount = 0
        var unchangedCount = 0
        var conflictCount = 0
        var conflictCopyCount = 0
        batch.notes.sortedWith(compareBy(VersionedNote::id, VersionedNote::revision)).forEach { note ->
            val result = mergeRemote(note)
            when (result.status) {
                NoteMergeStatus.acceptedRemote -> acceptedRemoteCount++
                NoteMergeStatus.keptLocal -> keptLocalCount++
                NoteMergeStatus.unchanged -> unchangedCount++
                NoteMergeStatus.conflict -> conflictCount++
            }
            if (result.conflictCopy != null) conflictCopyCount++
        }
        return NoteMergeBatchResult(
            acceptedRemoteCount = acceptedRemoteCount,
            keptLocalCount = keptLocalCount,
            unchangedCount = unchangedCount,
            conflictCount = conflictCount,
            conflictCopyCount = conflictCopyCount,
        )
    }

    private suspend fun requireCurrent(id: String, expectedRevision: NoteRevision): VersionedNote {
        val current = requireNotNull(store.get(id)) { "Note not found: $id" }
        require(current.revision == expectedRevision) { "The note changed since it was loaded" }
        return current
    }

    private suspend fun put(note: VersionedNote) {
        val notes = store.all().associateBy(VersionedNote::id).toMutableMap()
        notes[note.id] = note
        store.replace(notes.values.toList())
    }
}
