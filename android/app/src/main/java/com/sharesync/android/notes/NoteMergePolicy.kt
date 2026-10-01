package com.sharesync.android.notes

import java.nio.charset.StandardCharsets
import java.util.UUID

enum class NoteMergeStatus {
    unchanged,
    acceptedRemote,
    keptLocal,
    conflict,
}

data class NoteMergeResult(
    val status: NoteMergeStatus,
    val primary: VersionedNote,
    val conflictCopy: VersionedNote? = null,
)

class NoteMergePolicy {
    fun merge(local: VersionedNote, remote: VersionedNote): NoteMergeResult {
        require(local.id == remote.id) { "Only revisions of the same note can be merged" }

        if (local == remote) {
            return NoteMergeResult(NoteMergeStatus.unchanged, local)
        }
        if (remote.parentRevision == local.revision) {
            return NoteMergeResult(NoteMergeStatus.acceptedRemote, remote)
        }
        if (local.parentRevision == remote.revision) {
            return NoteMergeResult(NoteMergeStatus.keptLocal, local)
        }

        if (local.revision == remote.revision) {
            require(local.revision.deviceId != remote.revision.deviceId || local == remote) {
                "The same revision stamp cannot describe different note contents"
            }
        }

        val primary = choosePrimary(local, remote)
        val loser = if (primary === local) remote else local
        if (primary.isDeleted && loser.isDeleted) {
            return NoteMergeResult(NoteMergeStatus.conflict, primary)
        }

        return NoteMergeResult(
            status = NoteMergeStatus.conflict,
            primary = primary,
            conflictCopy = conflictCopy(originalId = local.id, loser = loser, other = primary),
        )
    }

    private fun choosePrimary(local: VersionedNote, remote: VersionedNote): VersionedNote {
        if (local.isDeleted != remote.isDeleted) {
            return if (local.isDeleted) local else remote
        }
        return if (local.revision >= remote.revision) local else remote
    }

    private fun conflictCopy(
        originalId: String,
        loser: VersionedNote,
        other: VersionedNote,
    ): VersionedNote {
        val pairKey = listOf(revisionKey(loser.revision), revisionKey(other.revision)).sorted().joinToString("|")
        val conflictId = UUID.nameUUIDFromBytes(
            "sharesync-note-conflict|$originalId|$pairKey".toByteArray(StandardCharsets.UTF_8)
        ).toString()
        val source = if (loser.isDeleted) other else loser
        return source.copy(
            id = conflictId,
            title = "[Conflict - ${source.revision.deviceId}] ${source.title}",
            conflictOfNoteId = originalId,
            deletedAtEpochMillis = null,
        )
    }

    private fun revisionKey(revision: NoteRevision): String {
        return "${revision.sequence}@${revision.deviceId}"
    }
}
