package com.sharesync.android.notes

import org.json.JSONArray
import org.json.JSONObject

class NoteJsonCodec {
    internal fun encodeNote(note: VersionedNote): JSONObject = note.toJson()

    internal fun decodeNote(json: JSONObject): VersionedNote = json.toNote()

    fun encode(notes: List<VersionedNote>): String {
        return JSONObject()
            .put("schemaVersion", STORE_SCHEMA_VERSION)
            .put(
                "notes",
                JSONArray().also { array -> notes.forEach { array.put(it.toJson()) } },
            )
            .toString(2)
    }

    fun decode(json: String): List<VersionedNote> {
        val root = JSONObject(json)
        require(root.getInt("schemaVersion") == STORE_SCHEMA_VERSION) { "Unsupported note store schema" }
        val notes = root.getJSONArray("notes")
        return buildList {
            for (index in 0 until notes.length()) {
                add(notes.getJSONObject(index).toNote())
            }
        }
    }

    private fun VersionedNote.toJson(): JSONObject {
        return JSONObject()
            .put("schemaVersion", schemaVersion)
            .put("id", id)
            .put("title", title)
            .put("markdownBody", markdownBody)
            .put("createdAtEpochMillis", createdAtEpochMillis)
            .put("updatedAtEpochMillis", updatedAtEpochMillis)
            .put("tags", JSONArray(tags))
            .put("revision", revision.toJson())
            .put("parentRevision", parentRevision?.toJson() ?: JSONObject.NULL)
            .put("deletedAtEpochMillis", deletedAtEpochMillis ?: JSONObject.NULL)
            .put("conflictOfNoteId", conflictOfNoteId ?: JSONObject.NULL)
    }

    private fun NoteRevision.toJson(): JSONObject {
        return JSONObject().put("sequence", sequence).put("deviceId", deviceId)
    }

    private fun JSONObject.toNote(): VersionedNote {
        return VersionedNote(
            schemaVersion = getInt("schemaVersion"),
            id = getString("id"),
            title = getString("title"),
            markdownBody = getString("markdownBody"),
            createdAtEpochMillis = getLong("createdAtEpochMillis"),
            updatedAtEpochMillis = getLong("updatedAtEpochMillis"),
            tags = getJSONArray("tags").toStrings().normalizedNoteTags(),
            revision = getJSONObject("revision").toRevision(),
            parentRevision = if (isNull("parentRevision")) null else getJSONObject("parentRevision").toRevision(),
            deletedAtEpochMillis = if (isNull("deletedAtEpochMillis")) null else getLong("deletedAtEpochMillis"),
            conflictOfNoteId = if (isNull("conflictOfNoteId")) null else getString("conflictOfNoteId"),
        )
    }

    private fun JSONObject.toRevision(): NoteRevision {
        return NoteRevision(sequence = getLong("sequence"), deviceId = getString("deviceId"))
    }

    private fun JSONArray.toStrings(): List<String> {
        return buildList {
            for (index in 0 until length()) add(getString(index))
        }
    }

    private companion object {
        const val STORE_SCHEMA_VERSION = 1
    }
}
