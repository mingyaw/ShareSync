package com.sharesync.android.notes

data class NoteRevision(
    val sequence: Long,
    val deviceId: String,
) : Comparable<NoteRevision> {
    init {
        require(sequence > 0) { "Revision sequence must be positive" }
        require(deviceId.isNotBlank()) { "Revision device ID must not be blank" }
    }

    override fun compareTo(other: NoteRevision): Int {
        return compareValuesBy(this, other, NoteRevision::sequence, NoteRevision::deviceId)
    }
}

data class VersionedNote(
    val schemaVersion: Int = CURRENT_SCHEMA_VERSION,
    val id: String,
    val title: String,
    val markdownBody: String,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long,
    val tags: List<String>,
    val revision: NoteRevision,
    val parentRevision: NoteRevision?,
    val deletedAtEpochMillis: Long?,
    val conflictOfNoteId: String? = null,
) {
    init {
        require(schemaVersion == CURRENT_SCHEMA_VERSION) { "Unsupported note schema version: $schemaVersion" }
        require(id.isNotBlank()) { "Note ID must not be blank" }
        require(createdAtEpochMillis >= 0) { "Creation time must not be negative" }
        require(updatedAtEpochMillis >= createdAtEpochMillis) { "Update time must not precede creation time" }
        require(deletedAtEpochMillis == null || deletedAtEpochMillis >= updatedAtEpochMillis) {
            "Deletion time must not precede update time"
        }
        require(parentRevision != revision) { "A revision cannot be its own parent" }
        require(conflictOfNoteId != id) { "A conflict copy cannot reference itself" }
    }

    val isDeleted: Boolean
        get() = deletedAtEpochMillis != null

    companion object {
        const val CURRENT_SCHEMA_VERSION = 1
    }
}

fun List<String>.normalizedNoteTags(): List<String> {
    return asSequence()
        .map(String::trim)
        .filter(String::isNotEmpty)
        .distinctBy(String::lowercase)
        .sortedBy(String::lowercase)
        .toList()
}
