package com.sharesync.android.sync

import java.io.File

interface SyncResultStore {
    suspend fun save(result: SyncResult)
    suspend fun latest(): SyncResult?

    suspend fun completedMediaAssetIds(): Set<String> {
        return latest()
            ?.results
            .orEmpty()
            .filter { item ->
                item.itemType == SyncItemType.media &&
                    (item.status == SyncItemStatus.synced || item.status == SyncItemStatus.skipped)
            }
            .map { item -> item.sourceItemId }
            .toSet()
    }
}

class InMemorySyncResultStore : SyncResultStore {
    private var latestResult: SyncResult? = null

    override suspend fun save(result: SyncResult) {
        latestResult = result
    }

    override suspend fun latest(): SyncResult? {
        return latestResult
    }
}

class FileSyncResultStore(
    private val file: File,
    private val codec: SyncResultJsonCodec = SyncResultJsonCodec(),
) : SyncResultStore {
    override suspend fun save(result: SyncResult) {
        file.parentFile?.mkdirs()
        file.writeText(codec.encode(result))
    }

    override suspend fun latest(): SyncResult? {
        if (!file.exists()) {
            return null
        }

        return runCatching { codec.decode(file.readText()) }.getOrNull()
    }

    companion object {
        fun defaultFile(filesDir: File): File {
            return File(File(filesDir, "ShareSync"), "latest-sync-result.json")
        }
    }
}
