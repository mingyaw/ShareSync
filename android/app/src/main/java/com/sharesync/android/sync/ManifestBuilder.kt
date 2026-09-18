package com.sharesync.android.sync

import com.sharesync.android.scanner.media.MediaScanner
import java.time.Instant

class ManifestBuilder(
    private val sourceDeviceId: String,
    private val mediaScanner: MediaScanner,
    private val syncResultStore: SyncResultStore,
) {
    suspend fun buildM0Manifest(limit: Int = 100, cursor: String? = null): SyncManifest {
        val safeLimit = limit.coerceIn(1, MAX_PAGE_SIZE)
        val offset = cursor?.removePrefix(CURSOR_PREFIX)?.toIntOrNull()?.coerceAtLeast(0) ?: 0
        val completedMediaAssetIds = syncResultStore.completedMediaAssetIds()
        val requiredPendingCount = offset + safeLimit + 1
        val scanChunkSize = (safeLimit * 5).coerceIn(safeLimit, MAX_SCAN_CHUNK_SIZE)
        val allPendingMedia = mutableListOf<MediaAsset>()
        var scanOffset = 0
        while (allPendingMedia.size < requiredPendingCount && scanOffset < MAX_ASSETS_SCANNED) {
            val scanned = mediaScanner.scanRecent(scanChunkSize, scanOffset)
            allPendingMedia += scanned
                .filter { asset -> asset.mediaType == MediaType.photo }
                .filterNot { asset -> asset.assetId in completedMediaAssetIds }
            scanOffset += scanned.size
            if (scanned.size < scanChunkSize) break
        }
        val pendingMedia = allPendingMedia.drop(offset).take(safeLimit)
        val hasMore = allPendingMedia.size > offset + pendingMedia.size
        val nextOffset = offset + pendingMedia.size

        return SyncManifest(
            sourceDeviceId = sourceDeviceId,
            generatedAt = Instant.now().toString(),
            cursor = cursor ?: "m0-${Instant.now().toEpochMilli()}",
            media = pendingMedia,
            pageSize = safeLimit,
            hasMore = hasMore,
            nextCursor = if (hasMore) "$CURSOR_PREFIX$nextOffset" else null,
        )
    }

    private companion object {
        const val CURSOR_PREFIX = "page:"
        const val MAX_PAGE_SIZE = 100
        const val MAX_SCAN_CHUNK_SIZE = 500
        const val MAX_ASSETS_SCANNED = 50_000
    }
}
