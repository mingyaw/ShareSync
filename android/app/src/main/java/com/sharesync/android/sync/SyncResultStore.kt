package com.sharesync.android.sync

import org.json.JSONArray
import org.json.JSONObject
import java.io.File

interface SyncResultStore {
    suspend fun save(result: SyncResult)
    suspend fun latest(): SyncResult?
    suspend fun latest(targetDeviceId: String): SyncResult?
    suspend fun clear()

    suspend fun completedMediaAssetIds(): Set<String> {
        return latest()
            ?.results
            .orEmpty()
            .filter { item ->
                item.itemType == SyncItemType.media &&
                    item.status.isCompletedForPhotoManifest
            }
            .map { item -> item.sourceItemId }
            .toSet()
    }

    suspend fun completedMediaAssetIds(targetDeviceId: String): Set<String> {
        return latest(targetDeviceId).completedMediaAssetIds()
    }

    suspend fun completedMediaAssetIds(targetDeviceIds: Set<String>): Set<String> {
        return targetDeviceIds
            .flatMap { targetDeviceId -> latest(targetDeviceId).completedMediaAssetIds() }
            .toSet()
    }
}

class InMemorySyncResultStore : SyncResultStore {
    private val resultsByTarget = LinkedHashMap<String, SyncResult>()
    private var latestTargetDeviceId: String? = null

    override suspend fun save(result: SyncResult) {
        resultsByTarget[result.targetDeviceId] = resultsByTarget[result.targetDeviceId].mergeWith(result)
        latestTargetDeviceId = result.targetDeviceId
    }

    override suspend fun latest(): SyncResult? {
        return latestTargetDeviceId?.let(resultsByTarget::get)
    }

    override suspend fun latest(targetDeviceId: String): SyncResult? {
        return resultsByTarget[targetDeviceId]
    }

    override suspend fun clear() {
        resultsByTarget.clear()
        latestTargetDeviceId = null
    }
}

class FileSyncResultStore(
    private val file: File,
    private val codec: SyncResultJsonCodec = SyncResultJsonCodec(),
) : SyncResultStore {
    override suspend fun save(result: SyncResult) {
        val snapshot = readSnapshot()
        snapshot.resultsByTarget[result.targetDeviceId] =
            snapshot.resultsByTarget[result.targetDeviceId].mergeWith(result)
        snapshot.latestTargetDeviceId = result.targetDeviceId
        file.parentFile?.mkdirs()
        val results = JSONArray()
        snapshot.resultsByTarget.values.forEach { storedResult ->
            results.put(JSONObject(codec.encode(storedResult)))
        }
        file.writeText(JSONObject()
            .put("schemaVersion", CURRENT_SCHEMA_VERSION)
            .put("latestTargetDeviceId", snapshot.latestTargetDeviceId)
            .put("results", results)
            .toString(2))
    }

    override suspend fun latest(): SyncResult? {
        val snapshot = readSnapshot()
        return snapshot.latestTargetDeviceId?.let(snapshot.resultsByTarget::get)
    }

    override suspend fun latest(targetDeviceId: String): SyncResult? {
        return readSnapshot().resultsByTarget[targetDeviceId]
    }

    private fun readSnapshot(): StoreSnapshot {
        if (!file.exists()) {
            return StoreSnapshot()
        }

        return runCatching {
            val json = file.readText()
            val root = JSONObject(json)
            if (root.optInt("schemaVersion") == CURRENT_SCHEMA_VERSION && root.has("results")) {
                val resultsByTarget = LinkedHashMap<String, SyncResult>()
                val results = root.getJSONArray("results")
                for (index in 0 until results.length()) {
                    val result = codec.decode(results.getJSONObject(index).toString())
                    resultsByTarget[result.targetDeviceId] = result
                }
                StoreSnapshot(
                    resultsByTarget = resultsByTarget,
                    latestTargetDeviceId = root.optString("latestTargetDeviceId")
                        .takeIf(resultsByTarget::containsKey),
                )
            } else {
                val legacyResult = if (root.has("schemaVersion") && root.has("result")) {
                    val schemaVersion = root.getInt("schemaVersion")
                    require(schemaVersion in 1 until CURRENT_SCHEMA_VERSION)
                    codec.decode(root.getJSONObject("result").toString())
                } else {
                    codec.decode(json)
                }
                StoreSnapshot(
                    resultsByTarget = linkedMapOf(legacyResult.targetDeviceId to legacyResult),
                    latestTargetDeviceId = legacyResult.targetDeviceId,
                )
            }
        }.getOrElse { StoreSnapshot() }
    }

    override suspend fun clear() {
        if (file.exists()) {
            file.delete()
        }
    }

    companion object {
        const val CURRENT_SCHEMA_VERSION = 3

        fun defaultFile(filesDir: File): File {
            return File(File(filesDir, "ShareSync"), "latest-sync-result.json")
        }
    }

    private data class StoreSnapshot(
        val resultsByTarget: LinkedHashMap<String, SyncResult> = LinkedHashMap(),
        var latestTargetDeviceId: String? = null,
    )
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

private val SyncItemStatus.isCompletedForPhotoManifest: Boolean
    get() = this == SyncItemStatus.synced || this == SyncItemStatus.skipped

private fun SyncResult?.completedMediaAssetIds(): Set<String> {
    return this
        ?.results
        .orEmpty()
        .filter { item ->
            item.itemType == SyncItemType.media && item.status.isCompletedForPhotoManifest
        }
        .map { item -> item.sourceItemId }
        .toSet()
}
