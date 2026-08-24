package com.sharesync.android.sync

import com.sharesync.android.scanner.media.MediaScanner
import java.time.Instant

class ManifestBuilder(
    private val sourceDeviceId: String,
    private val mediaScanner: MediaScanner,
    private val syncResultStore: SyncResultStore,
) {
    suspend fun buildM0Manifest(limit: Int = 100): SyncManifest {
        val completedMediaAssetIds = syncResultStore.completedMediaAssetIds()
        val scanLimit = (limit * 5).coerceIn(limit, 500)
        val pendingMedia = mediaScanner
            .scanRecent(scanLimit)
            .filterNot { asset -> asset.assetId in completedMediaAssetIds }
            .take(limit)

        return SyncManifest(
            sourceDeviceId = sourceDeviceId,
            generatedAt = Instant.now().toString(),
            cursor = "m0-${Instant.now().toEpochMilli()}",
            media = pendingMedia,
        )
    }
}
