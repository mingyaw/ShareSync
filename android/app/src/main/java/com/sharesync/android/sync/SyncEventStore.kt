package com.sharesync.android.sync

import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class SyncEvent(
    val syncBatchId: String,
    val targetDeviceId: String,
    val recordedAtEpochMillis: Long,
    val syncedCount: Int,
    val skippedCount: Int,
    val failedCount: Int,
    val conflictedCount: Int,
) {
    val successfulCount: Int
        get() = syncedCount + skippedCount

    val isComplete: Boolean
        get() = failedCount == 0 && conflictedCount == 0

    companion object {
        fun fromResult(result: SyncResult, recordedAtEpochMillis: Long): SyncEvent {
            return SyncEvent(
                syncBatchId = result.syncBatchId,
                targetDeviceId = result.targetDeviceId,
                recordedAtEpochMillis = recordedAtEpochMillis,
                syncedCount = result.results.count { it.status == SyncItemStatus.synced },
                skippedCount = result.results.count { it.status == SyncItemStatus.skipped },
                failedCount = result.results.count { it.status == SyncItemStatus.failed },
                conflictedCount = result.results.count { it.status == SyncItemStatus.conflicted },
            )
        }
    }
}

interface SyncEventStore {
    suspend fun append(event: SyncEvent)
    suspend fun latest(): SyncEvent?
    suspend fun all(): List<SyncEvent>
    suspend fun clear()
}

class InMemorySyncEventStore : SyncEventStore {
    private val events = mutableListOf<SyncEvent>()

    override suspend fun append(event: SyncEvent) {
        events.add(event)
    }

    override suspend fun latest(): SyncEvent? {
        return events.lastOrNull()
    }

    override suspend fun all(): List<SyncEvent> {
        return events.toList()
    }

    override suspend fun clear() {
        events.clear()
    }
}

class FileSyncEventStore(
    private val file: File,
    private val codec: SyncEventJsonCodec = SyncEventJsonCodec(),
) : SyncEventStore {
    override suspend fun append(event: SyncEvent) {
        val updatedEvents = (all() + event).takeLast(MAX_EVENTS)
        file.parentFile?.mkdirs()
        file.writeText(codec.encode(updatedEvents))
    }

    override suspend fun latest(): SyncEvent? {
        return all().lastOrNull()
    }

    override suspend fun all(): List<SyncEvent> {
        if (!file.exists()) {
            return emptyList()
        }

        return runCatching { codec.decode(file.readText()) }.getOrDefault(emptyList())
    }

    override suspend fun clear() {
        if (file.exists()) {
            file.delete()
        }
    }

    companion object {
        private const val MAX_EVENTS = 50

        fun defaultFile(filesDir: File): File {
            return File(File(filesDir, "ShareSync"), "sync-events.json")
        }
    }
}

class SyncEventJsonCodec {
    fun encode(events: List<SyncEvent>): String {
        return JSONArray().also { array ->
            events.forEach { event ->
                array.put(
                    JSONObject()
                        .put("syncBatchId", event.syncBatchId)
                        .put("targetDeviceId", event.targetDeviceId)
                        .put("recordedAtEpochMillis", event.recordedAtEpochMillis)
                        .put("syncedCount", event.syncedCount)
                        .put("skippedCount", event.skippedCount)
                        .put("failedCount", event.failedCount)
                        .put("conflictedCount", event.conflictedCount)
                )
            }
        }.toString(2)
    }

    fun decode(json: String): List<SyncEvent> {
        val array = JSONArray(json)
        return buildList {
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                add(
                    SyncEvent(
                        syncBatchId = item.getString("syncBatchId"),
                        targetDeviceId = item.getString("targetDeviceId"),
                        recordedAtEpochMillis = item.getLong("recordedAtEpochMillis"),
                        syncedCount = item.getInt("syncedCount"),
                        skippedCount = item.getInt("skippedCount"),
                        failedCount = item.getInt("failedCount"),
                        conflictedCount = item.getInt("conflictedCount"),
                    )
                )
            }
        }
    }
}
