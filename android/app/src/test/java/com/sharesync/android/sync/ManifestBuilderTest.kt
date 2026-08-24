package com.sharesync.android.sync

import com.sharesync.android.SuspendBridge
import com.sharesync.android.scanner.media.MediaScanner
import org.junit.Assert.assertEquals
import org.junit.Test

class ManifestBuilderTest {
    @Test
    fun buildM0ManifestExcludesSyncedAndSkippedMediaResults() {
        val scanner = FakeMediaScanner(
            assets = listOf(
                mediaAsset("media-synced"),
                mediaAsset("media-skipped"),
                mediaAsset("media-failed"),
                mediaAsset("media-new"),
            )
        )
        val store = InMemorySyncResultStore()
        SuspendBridge.runBlocking {
            store.save(
                SyncResult(
                    syncBatchId = "batch-001",
                    targetDeviceId = "ios-device-001",
                    results = listOf(
                        syncItem("media-synced", SyncItemStatus.synced),
                        syncItem("media-skipped", SyncItemStatus.skipped),
                        syncItem("media-failed", SyncItemStatus.failed),
                    ),
                )
            )
        }

        val manifest = SuspendBridge.runBlocking {
            ManifestBuilder(
                sourceDeviceId = "android-device-001",
                mediaScanner = scanner,
                syncResultStore = store,
            ).buildM0Manifest(limit = 100)
        }

        assertEquals(listOf("media-failed", "media-new"), manifest.media.map { it.assetId })
    }

    @Test
    fun buildM0ManifestScansBeyondLimitBeforeFilteringCompletedMedia() {
        val scanner = FakeMediaScanner(
            assets = listOf(
                mediaAsset("media-synced"),
                mediaAsset("media-new-1"),
                mediaAsset("media-new-2"),
            )
        )
        val store = InMemorySyncResultStore()
        SuspendBridge.runBlocking {
            store.save(
                SyncResult(
                    syncBatchId = "batch-001",
                    targetDeviceId = "ios-device-001",
                    results = listOf(syncItem("media-synced", SyncItemStatus.synced)),
                )
            )
        }

        val manifest = SuspendBridge.runBlocking {
            ManifestBuilder(
                sourceDeviceId = "android-device-001",
                mediaScanner = scanner,
                syncResultStore = store,
            ).buildM0Manifest(limit = 2)
        }

        assertEquals(10, scanner.lastLimit)
        assertEquals(listOf("media-new-1", "media-new-2"), manifest.media.map { it.assetId })
    }

    private fun syncItem(sourceItemId: String, status: SyncItemStatus): SyncItemResult {
        return SyncItemResult(
            itemType = SyncItemType.media,
            sourceItemId = sourceItemId,
            targetItemId = null,
            status = status,
            errorCode = null,
        )
    }

    private fun mediaAsset(assetId: String): MediaAsset {
        return MediaAsset(
            assetId = assetId,
            sourceDeviceId = "android-device-001",
            mediaType = MediaType.photo,
            fileName = "$assetId.jpg",
            mimeType = "image/jpeg",
            size = 1024,
        )
    }
}

private class FakeMediaScanner(
    private val assets: List<MediaAsset>,
) : MediaScanner {
    var lastLimit: Int = 0
        private set

    override suspend fun scanRecent(limit: Int): List<MediaAsset> {
        lastLimit = limit
        return assets.take(limit)
    }
}
