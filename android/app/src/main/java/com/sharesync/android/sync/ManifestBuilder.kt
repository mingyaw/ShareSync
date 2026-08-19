package com.sharesync.android.sync

import com.sharesync.android.scanner.media.MediaScanner
import java.time.Instant

class ManifestBuilder(
    private val sourceDeviceId: String,
    private val mediaScanner: MediaScanner,
) {
    suspend fun buildM0Manifest(limit: Int = 100): SyncManifest {
        return SyncManifest(
            sourceDeviceId = sourceDeviceId,
            generatedAt = Instant.now().toString(),
            cursor = "m0-${Instant.now().toEpochMilli()}",
            media = mediaScanner.scanRecent(limit),
        )
    }
}

