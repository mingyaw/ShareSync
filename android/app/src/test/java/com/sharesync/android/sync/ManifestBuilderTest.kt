package com.sharesync.android.sync

import com.sharesync.android.SuspendBridge
import com.sharesync.android.scanner.media.MediaScanCursor
import com.sharesync.android.scanner.media.MediaScanner
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

class ManifestBuilderTest {
    @Test
    fun buildPhotoManifestExcludesSyncedAndSkippedMediaResults() {
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
            ).buildPhotoManifest(limit = 100)
        }

        assertEquals(listOf("media-failed", "media-new"), manifest.media.map { it.assetId })
    }

    @Test
    fun buildPhotoManifestExcludesPhotoAfterFailedItemIsRetriedSuccessfully() {
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
            ).buildPhotoManifest(limit = 100)
        }

        assertEquals(listOf("media-new"), manifest.media.map { it.assetId })
    }

    @Test
    fun buildPhotoManifestKeepsConflictedMediaForRetry() {
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
            ).buildPhotoManifest(limit = 100)
        }

        assertEquals(listOf("media-conflicted", "media-new"), manifest.media.map { it.assetId })
    }

    @Test
    fun buildPhotoManifestScansBeyondLimitBeforeFilteringCompletedMedia() {
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
            ).buildPhotoManifest(limit = 2)
        }

        assertEquals(10, scanner.lastLimit)
        assertEquals(listOf("media-new-1", "media-new-2"), manifest.media.map { it.assetId })
    }

    @Test
    fun buildPhotoManifestIncludesPhotosOnly() {
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
            ).buildPhotoManifest(limit = 100)
        }

        assertEquals(listOf("photo-001", "photo-002"), manifest.media.map { it.assetId })
        assertEquals(listOf(MediaType.photo, MediaType.photo), manifest.media.map { it.mediaType })
    }

    @Test
    fun buildPhotoManifestReturnsStablePagesWithoutOverlap() {
        val scanner = FakeMediaScanner(
            assets = (1..5).map { index -> mediaAsset("media-$index") },
        )
        val builder = ManifestBuilder(
            sourceDeviceId = "android-device-001",
            mediaScanner = scanner,
            syncResultStore = InMemorySyncResultStore(),
        )

        val firstPage = SuspendBridge.runBlocking { builder.buildPhotoManifest(limit = 2) }
        val secondPage = SuspendBridge.runBlocking {
            builder.buildPhotoManifest(limit = 2, pageCursor = firstPage.nextCursor)
        }

        assertEquals(listOf("media-1", "media-2"), firstPage.media.map { it.assetId })
        assertEquals(true, firstPage.hasMore)
        assertEquals("page-v2:0:0:0:0:2", firstPage.nextCursor)
        assertEquals(listOf("media-3", "media-4"), secondPage.media.map { it.assetId })
        assertEquals(true, secondPage.hasMore)
        assertEquals("page-v2:0:0:0:0:4", secondPage.nextCursor)
    }

    @Test
    fun buildPhotoManifestPagesBeyondFirstFiveHundredPhotos() {
        val scanner = FakeMediaScanner(
            assets = (1..620).map { index -> mediaAsset("media-${index.toString().padStart(3, '0')}") },
        )
        val builder = ManifestBuilder(
            sourceDeviceId = "android-device-001",
            mediaScanner = scanner,
            syncResultStore = InMemorySyncResultStore(),
        )

        val page = SuspendBridge.runBlocking {
            builder.buildPhotoManifest(limit = 100, pageCursor = "page-v2:0:0:0:0:500")
        }

        assertEquals(100, page.media.size)
        assertEquals("media-501", page.media.first().assetId)
        assertEquals("media-600", page.media.last().assetId)
        assertEquals(true, page.hasMore)
        assertEquals("page-v2:0:0:0:0:600", page.nextCursor)
        assertEquals(2, scanner.requestCount)
    }

    @Test
    fun buildPhotoManifestUsesIncrementalCursorAndStableSnapshotWindow() {
        val assets = listOf(
            mediaStoreAsset(id = 14, modifiedAtSeconds = 1_004),
            mediaStoreAsset(id = 13, modifiedAtSeconds = 1_003),
            mediaStoreAsset(id = 12, modifiedAtSeconds = 1_002),
            mediaStoreAsset(id = 11, modifiedAtSeconds = 1_001),
        )
        val scanner = FakeMediaScanner(assets)
        val builder = ManifestBuilder(
            sourceDeviceId = "android-device-001",
            mediaScanner = scanner,
            syncResultStore = InMemorySyncResultStore(),
        )

        val firstPage = SuspendBridge.runBlocking {
            builder.buildPhotoManifest(limit = 2, sinceCursor = "media-v1:1000:10")
        }
        val secondPage = SuspendBridge.runBlocking {
            builder.buildPhotoManifest(
                limit = 2,
                sinceCursor = "media-v1:1000:10",
                pageCursor = firstPage.nextCursor,
            )
        }

        assertEquals("media-v1:1004:14", firstPage.cursor)
        assertEquals(listOf("mediastore-1-14", "mediastore-1-13"), firstPage.media.map { it.assetId })
        assertEquals("page-v2:1000:10:1004:14:2", firstPage.nextCursor)
        assertEquals("media-v1:1004:14", secondPage.cursor)
        assertEquals(listOf("mediastore-1-12", "mediastore-1-11"), secondPage.media.map { it.assetId })
        assertEquals(false, secondPage.hasMore)
        assertEquals(MediaScanCursor(1_000, 10), scanner.lastModifiedAfter)
        assertEquals(MediaScanCursor(1_004, 14), scanner.lastModifiedAtOrBefore)
    }

    @Test
    fun buildPhotoManifestUsesMediaStoreIdToBreakModificationTimeTies() {
        val scanner = FakeMediaScanner(
            listOf(
                mediaStoreAsset(id = 12, modifiedAtSeconds = 1_000),
                mediaStoreAsset(id = 11, modifiedAtSeconds = 1_000),
                mediaStoreAsset(id = 10, modifiedAtSeconds = 1_000),
                mediaStoreAsset(id = 99, modifiedAtSeconds = 999),
            )
        )

        val manifest = SuspendBridge.runBlocking {
            ManifestBuilder(
                sourceDeviceId = "android-device-001",
                mediaScanner = scanner,
                syncResultStore = InMemorySyncResultStore(),
            ).buildPhotoManifest(limit = 100, sinceCursor = "media-v1:1000:10")
        }

        assertEquals(listOf("mediastore-1-12", "mediastore-1-11"), manifest.media.map { it.assetId })
        assertEquals("media-v1:1000:12", manifest.cursor)
    }

    @Test
    fun buildPhotoManifestFiltersCompletedMediaAfterFileStoreReloadWithMixedStates() {
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
                ).buildPhotoManifest(limit = 100)
            }

            assertEquals(listOf("media-failed", "media-conflicted", "media-new"), manifest.media.map { it.assetId })
        } finally {
            file.delete()
            directory.delete()
        }
    }

    @Test
    fun buildPhotoManifestIncludesCompletedMediaAgainAfterFileStoreClear() {
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
                ).buildPhotoManifest(limit = 100)
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

    private fun mediaStoreAsset(id: Long, modifiedAtSeconds: Long): MediaAsset {
        return mediaAsset("mediastore-1-$id").copy(
            modifiedAt = java.time.Instant.ofEpochSecond(modifiedAtSeconds).toString(),
        )
    }
}

private class FakeMediaScanner(
    private val assets: List<MediaAsset>,
) : MediaScanner {
    var lastLimit: Int = 0
        private set
    var requestCount: Int = 0
        private set
    var lastModifiedAfter: MediaScanCursor? = null
        private set
    var lastModifiedAtOrBefore: MediaScanCursor? = null
        private set

    override suspend fun scanRecent(
        limit: Int,
        offset: Int,
        modifiedAfter: MediaScanCursor?,
        modifiedAtOrBefore: MediaScanCursor?,
    ): List<MediaAsset> {
        lastLimit = limit
        requestCount += 1
        lastModifiedAfter = modifiedAfter
        lastModifiedAtOrBefore = modifiedAtOrBefore
        return assets
            .filter { asset ->
                val cursor = asset.scanCursor() ?: return@filter modifiedAfter == null && modifiedAtOrBefore == null
                (modifiedAfter == null || cursor > modifiedAfter) &&
                    (modifiedAtOrBefore == null || cursor <= modifiedAtOrBefore)
            }
            .drop(offset)
            .take(limit)
    }

    private fun MediaAsset.scanCursor(): MediaScanCursor? {
        val seconds = modifiedAt?.let { runCatching { java.time.Instant.parse(it).epochSecond }.getOrNull() } ?: return null
        val id = assetId.substringAfterLast("-").toLongOrNull() ?: return null
        return MediaScanCursor(seconds, id)
    }

    private operator fun MediaScanCursor.compareTo(other: MediaScanCursor): Int {
        val modifiedComparison = modifiedAtEpochSeconds.compareTo(other.modifiedAtEpochSeconds)
        return if (modifiedComparison != 0) modifiedComparison else mediaStoreId.compareTo(other.mediaStoreId)
    }
}
