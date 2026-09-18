package com.sharesync.android.sync

import com.sharesync.android.scanner.media.MediaScanner
import com.sharesync.android.scanner.media.MediaScanCursor
import java.time.Instant

class ManifestBuilder(
    private val sourceDeviceId: String,
    private val mediaScanner: MediaScanner,
    private val syncResultStore: SyncResultStore,
) {
    suspend fun buildM0Manifest(
        limit: Int = 100,
        sinceCursor: String? = null,
        pageCursor: String? = null,
    ): SyncManifest {
        val safeLimit = limit.coerceIn(1, MAX_PAGE_SIZE)
        val legacyPageCursor = sinceCursor?.takeIf { it.startsWith(LEGACY_PAGE_CURSOR_PREFIX) }
        val page = PageCursor.decode(pageCursor ?: legacyPageCursor)
        val modifiedAfter = page?.modifiedAfter ?: IncrementalCursor.decode(sinceCursor)?.scanCursor
        var snapshotUpperBound = page?.snapshotUpperBound
        val offset = page?.pendingOffset
            ?: legacyPageCursor?.removePrefix(LEGACY_PAGE_CURSOR_PREFIX)?.toIntOrNull()?.coerceAtLeast(0)
            ?: 0
        val completedMediaAssetIds = syncResultStore.completedMediaAssetIds()
        val requiredPendingCount = offset + safeLimit + 1
        val scanChunkSize = (safeLimit * 5).coerceIn(safeLimit, MAX_SCAN_CHUNK_SIZE)
        val allPendingMedia = mutableListOf<MediaAsset>()
        var scanOffset = 0
        while (allPendingMedia.size < requiredPendingCount && scanOffset < MAX_ASSETS_SCANNED) {
            val scanned = mediaScanner.scanRecent(
                limit = scanChunkSize,
                offset = scanOffset,
                modifiedAfter = modifiedAfter,
                modifiedAtOrBefore = snapshotUpperBound,
            )
            if (snapshotUpperBound == null) {
                snapshotUpperBound = scanned.firstNotNullOfOrNull(::scanCursorFor)
            }
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
            cursor = IncrementalCursor(snapshotUpperBound ?: modifiedAfter ?: MediaScanCursor(0, 0)).encode(),
            media = pendingMedia,
            pageSize = safeLimit,
            hasMore = hasMore,
            nextCursor = if (hasMore) {
                PageCursor(
                    modifiedAfter = modifiedAfter,
                    snapshotUpperBound = snapshotUpperBound,
                    pendingOffset = nextOffset,
                ).encode()
            } else {
                null
            },
        )
    }

    private fun scanCursorFor(asset: MediaAsset): MediaScanCursor? {
        val modifiedAt = asset.modifiedAt?.let { runCatching { Instant.parse(it) }.getOrNull() } ?: return null
        val mediaStoreId = asset.assetId.substringAfterLast("-").toLongOrNull() ?: return null
        return MediaScanCursor(modifiedAt.epochSecond, mediaStoreId)
    }

    private data class IncrementalCursor(val scanCursor: MediaScanCursor) {
        fun encode(): String = "$INCREMENTAL_CURSOR_PREFIX${scanCursor.modifiedAtEpochSeconds}:${scanCursor.mediaStoreId}"

        companion object {
            fun decode(value: String?): IncrementalCursor? {
                if (value == null || !value.startsWith(INCREMENTAL_CURSOR_PREFIX)) return null
                val parts = value.removePrefix(INCREMENTAL_CURSOR_PREFIX).split(":")
                if (parts.size != 2) return null
                return IncrementalCursor(
                    MediaScanCursor(
                        modifiedAtEpochSeconds = parts[0].toLongOrNull() ?: return null,
                        mediaStoreId = parts[1].toLongOrNull() ?: return null,
                    )
                )
            }
        }
    }

    private data class PageCursor(
        val modifiedAfter: MediaScanCursor?,
        val snapshotUpperBound: MediaScanCursor?,
        val pendingOffset: Int,
    ) {
        fun encode(): String {
            val after = modifiedAfter ?: MediaScanCursor(0, 0)
            val upper = snapshotUpperBound ?: after
            return "$PAGE_CURSOR_PREFIX${after.modifiedAtEpochSeconds}:${after.mediaStoreId}:${upper.modifiedAtEpochSeconds}:${upper.mediaStoreId}:$pendingOffset"
        }

        companion object {
            fun decode(value: String?): PageCursor? {
                if (value == null || !value.startsWith(PAGE_CURSOR_PREFIX)) return null
                val parts = value.removePrefix(PAGE_CURSOR_PREFIX).split(":")
                if (parts.size != 5) return null
                val after = MediaScanCursor(parts[0].toLongOrNull() ?: return null, parts[1].toLongOrNull() ?: return null)
                    .takeUnless { it.modifiedAtEpochSeconds == 0L && it.mediaStoreId == 0L }
                val upper = MediaScanCursor(parts[2].toLongOrNull() ?: return null, parts[3].toLongOrNull() ?: return null)
                    .takeUnless { it.modifiedAtEpochSeconds == 0L && it.mediaStoreId == 0L }
                return PageCursor(after, upper, parts[4].toIntOrNull()?.coerceAtLeast(0) ?: return null)
            }
        }
    }

    private companion object {
        const val INCREMENTAL_CURSOR_PREFIX = "media-v1:"
        const val PAGE_CURSOR_PREFIX = "page-v2:"
        const val LEGACY_PAGE_CURSOR_PREFIX = "page:"
        const val MAX_PAGE_SIZE = 100
        const val MAX_SCAN_CHUNK_SIZE = 500
        const val MAX_ASSETS_SCANNED = 50_000
    }
}
