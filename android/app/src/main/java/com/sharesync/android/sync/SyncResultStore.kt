package com.sharesync.android.sync

import org.json.JSONObject
import java.io.File

interface SyncResultStore {
    suspend fun save(result: SyncResult)
    suspend fun latest(): SyncResult?
    suspend fun clear()

    suspend fun completedMediaAssetIds(): Set<String> {
        return latest()
            ?.results
            .orEmpty()
            .filter { item ->
                item.itemType == SyncItemType.media &&
                    item.status.isCompletedForM0Manifest
            }
            .map { item -> item.sourceItemId }
            .toSet()
    }
}

class InMemorySyncResultStore : SyncResultStore {
    private var latestResult: SyncResult? = null

    override suspend fun save(result: SyncResult) {
        latestResult = latestResult.mergeWith(result)
    }

    override suspend fun latest(): SyncResult? {
        return latestResult
    }

    override suspend fun clear() {
        latestResult = null
    }
}

class FileSyncResultStore(
    private val file: File,
    private val codec: SyncResultJsonCodec = SyncResultJsonCodec(),
) : SyncResultStore {
    override suspend fun save(result: SyncResult) {
        val mergedResult = latest().mergeWith(result)
        file.parentFile?.mkdirs()
        file.writeText(
            JSONObject()
                .put("schemaVersion", CURRENT_SCHEMA_VERSION)
                .put("result", JSONObject(codec.encode(mergedResult)))
                .toString(2),
        )
    }

    override suspend fun latest(): SyncResult? {
        if (!file.exists()) {
            return null
        }

        return runCatching {
            val json = file.readText()
            val root = JSONObject(json)
            if (root.has("schemaVersion") && root.has("result")) {
                val schemaVersion = root.getInt("schemaVersion")
                require(schemaVersion in 1..CURRENT_SCHEMA_VERSION)
                codec.decode(root.getJSONObject("result").toString())
            } else {
                codec.decode(json)
            }
        }.getOrNull()
    }

    override suspend fun clear() {
        if (file.exists()) {
            file.delete()
        }
    }

    companion object {
        const val CURRENT_SCHEMA_VERSION = 2

        fun defaultFile(filesDir: File): File {
            return File(File(filesDir, "ShareSync"), "latest-sync-result.json")
        }
    }
}

private fun SyncResult?.mergeWith(incoming: SyncResult): SyncResult {
    if (this == null) {
        return incoming
    }

    val mergedByItemKey = LinkedHashMap<SyncResultItemKey, SyncItemResult>()
    results.forEach { item ->
        mergedByItemKey[item.key()] = item
    }
    incoming.results.forEach { item ->
        mergedByItemKey[item.key()] = item
    }

    return SyncResult(
        syncBatchId = incoming.syncBatchId,
        targetDeviceId = incoming.targetDeviceId,
        results = mergedByItemKey.values.toList(),
    )
}

private data class SyncResultItemKey(
    val itemType: SyncItemType,
    val sourceItemId: String,
)

private fun SyncItemResult.key(): SyncResultItemKey {
    return SyncResultItemKey(
        itemType = itemType,
        sourceItemId = sourceItemId,
    )
}

private val SyncItemStatus.isCompletedForM0Manifest: Boolean
    get() = this == SyncItemStatus.synced || this == SyncItemStatus.skipped
