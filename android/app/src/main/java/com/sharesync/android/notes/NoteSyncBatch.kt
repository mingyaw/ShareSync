package com.sharesync.android.notes

import org.json.JSONArray
import org.json.JSONObject

data class NoteSyncBatch(
    val schemaVersion: Int = CURRENT_SCHEMA_VERSION,
    val batchId: String,
    val sourceDeviceId: String,
    val generatedAtEpochMillis: Long,
    val notes: List<VersionedNote>,
) {
    init {
        require(schemaVersion == CURRENT_SCHEMA_VERSION) { "Unsupported note sync batch schema" }
        require(batchId.isNotBlank()) { "Batch ID must not be blank" }
        require(sourceDeviceId.isNotBlank()) { "Source device ID must not be blank" }
        require(generatedAtEpochMillis >= 0) { "Batch generation time must not be negative" }
        require(notes.map(VersionedNote::id).distinct().size == notes.size) {
            "A note sync batch cannot contain duplicate note IDs"
        }
    }

    companion object {
        const val CURRENT_SCHEMA_VERSION = 1
    }
}

class NoteSyncBatchCodec(
    private val noteCodec: NoteJsonCodec = NoteJsonCodec(),
) {
    fun encode(batch: NoteSyncBatch): String {
        return JSONObject()
            .put("schemaVersion", batch.schemaVersion)
            .put("batchId", batch.batchId)
            .put("sourceDeviceId", batch.sourceDeviceId)
            .put("generatedAtEpochMillis", batch.generatedAtEpochMillis)
            .put(
                "notes",
                JSONArray().also { array ->
                    batch.notes.sortedBy(VersionedNote::id).forEach {
                        array.put(noteCodec.encodeNote(it))
                    }
                },
            )
            .toString(2)
    }

    fun decode(json: String): NoteSyncBatch {
        val root = JSONObject(json)
        val notes = root.getJSONArray("notes")
        return NoteSyncBatch(
            schemaVersion = root.getInt("schemaVersion"),
            batchId = root.getString("batchId"),
            sourceDeviceId = root.getString("sourceDeviceId"),
            generatedAtEpochMillis = root.getLong("generatedAtEpochMillis"),
            notes = buildList {
                for (index in 0 until notes.length()) {
                    add(noteCodec.decodeNote(notes.getJSONObject(index)))
                }
            },
        )
    }
}
