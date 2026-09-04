package com.sharesync.android.sync

import com.sharesync.android.SuspendBridge
import com.sharesync.android.scanner.media.MediaScanner
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

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
    fun buildM0ManifestExcludesPhotoAfterFailedItemIsRetriedSuccessfully() {
        val scanner = FakeMediaScanner(
            assets = listOf(
                mediaAsset("media-retried"),
                mediaAsset("media-new"),
            )
        )
        val store = InMemorySyncResultStore()
        SuspendBridge.runBlocking {
            store.save(
                SyncResult(
                    syncBatchId = "batch-001",
                    targetDeviceId = "ios-device-001",
                    results = listOf(syncItem("media-retried", SyncItemStatus.failed)),
                )
            )
            store.save(
                SyncResult(
                    syncBatchId = "batch-002",
                    targetDeviceId = "ios-device-001",
                    results = listOf(syncItem("media-retried", SyncItemStatus.synced)),
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

        assertEquals(listOf("media-new"), manifest.media.map { it.assetId })
    }

    @Test
    fun buildM0ManifestKeepsConflictedMediaForRetry() {
        val scanner = FakeMediaScanner(
            assets = listOf(
                mediaAsset("media-conflicted"),
                mediaAsset("media-new"),
            )
        )
        val store = InMemorySyncResultStore()
        SuspendBridge.runBlocking {
            store.save(
                SyncResult(
                    syncBatchId = "batch-001",
                    targetDeviceId = "ios-device-001",
                    results = listOf(syncItem("media-conflicted", SyncItemStatus.conflicted)),
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

        assertEquals(listOf("media-conflicted", "media-new"), manifest.media.map { it.assetId })
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

    @Test
    fun buildM0ManifestIncludesPhotosOnly() {
        val scanner = FakeMediaScanner(
            assets = listOf(
                mediaAsset("photo-001", mediaType = MediaType.photo),
                mediaAsset("video-001", mediaType = MediaType.video),
                mediaAsset("photo-002", mediaType = MediaType.photo),
            )
        )
        val store = InMemorySyncResultStore()

        val manifest = SuspendBridge.runBlocking {
            ManifestBuilder(
                sourceDeviceId = "android-device-001",
                mediaScanner = scanner,
                syncResultStore = store,
            ).buildM0Manifest(limit = 100)
        }

        assertEquals(listOf("photo-001", "photo-002"), manifest.media.map { it.assetId })
        assertEquals(listOf(MediaType.photo, MediaType.photo), manifest.media.map { it.mediaType })
    }

    @Test
    fun buildM0ManifestFiltersCompletedMediaAfterFileStoreReloadWithMixedStates() {
        val scanner = FakeMediaScanner(
            assets = listOf(
                mediaAsset("media-synced"),
                mediaAsset("media-skipped"),
                mediaAsset("media-failed"),
                mediaAsset("media-conflicted"),
                mediaAsset("media-new"),
            )
        )
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncManifestBuilderTest-${System.nanoTime()}")
        val file = File(directory, "latest-sync-result.json")
        val store = FileSyncResultStore(file = file)

        try {
            SuspendBridge.runBlocking {
                store.save(
                    SyncResult(
                        syncBatchId = "batch-001",
                        targetDeviceId = "ios-device-001",
                        results = listOf(
                            syncItem("media-synced", SyncItemStatus.synced),
                            syncItem("media-skipped", SyncItemStatus.skipped),
                            syncItem("media-failed", SyncItemStatus.failed),
                            syncItem("media-conflicted", SyncItemStatus.conflicted),
                        ),
                    )
                )
            }

            val manifest = SuspendBridge.runBlocking {
                ManifestBuilder(
                    sourceDeviceId = "android-device-001",
                    mediaScanner = scanner,
                    syncResultStore = FileSyncResultStore(file = file),
                ).buildM0Manifest(limit = 100)
            }

            assertEquals(listOf("media-failed", "media-conflicted", "media-new"), manifest.media.map { it.assetId })
        } finally {
            file.delete()
            directory.delete()
        }
    }

    @Test
    fun buildM0ManifestIncludesCompletedMediaAgainAfterFileStoreClear() {
        val scanner = FakeMediaScanner(
            assets = listOf(
                mediaAsset("media-synced"),
                mediaAsset("media-new"),
            )
        )
        val directory = File(System.getProperty("java.io.tmpdir"), "ShareSyncManifestBuilderTest-${System.nanoTime()}")
        val file = File(directory, "latest-sync-result.json")
        val store = FileSyncResultStore(file = file)

        try {
            SuspendBridge.runBlocking {
                store.save(
                    SyncResult(
                        syncBatchId = "batch-001",
                        targetDeviceId = "ios-device-001",
                        results = listOf(syncItem("media-synced", SyncItemStatus.synced)),
                    )
                )
                store.clear()
            }

            val manifest = SuspendBridge.runBlocking {
                ManifestBuilder(
                    sourceDeviceId = "android-device-001",
                    mediaScanner = scanner,
                    syncResultStore = FileSyncResultStore(file = file),
                ).buildM0Manifest(limit = 100)
            }

            assertEquals(listOf("media-synced", "media-new"), manifest.media.map { it.assetId })
        } finally {
            file.delete()
            directory.delete()
        }
    }

    private fun syncItem(sourceItemId: String, status: SyncItemStatus): SyncItemResult {
        return SyncItemResult(
            itemType = SyncItemType.media,
            sourceItemId = sourceItemId,
            targetItemId = null,
            status = status,
            errorCode = if (status == SyncItemStatus.failed || status == SyncItemStatus.conflicted) "SS-NET-002" else null,
        )
    }

    private fun mediaAsset(assetId: String, mediaType: MediaType = MediaType.photo): MediaAsset {
        val extension = if (mediaType == MediaType.photo) "jpg" else "mp4"
        val mimeType = if (mediaType == MediaType.photo) "image/jpeg" else "video/mp4"
        return MediaAsset(
            assetId = assetId,
            sourceDeviceId = "android-device-001",
            mediaType = mediaType,
            fileName = "$assetId.$extension",
            mimeType = mimeType,
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
