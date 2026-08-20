package com.sharesync.android.scanner.media

import android.content.ContentResolver
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import com.sharesync.android.sync.MediaAsset
import com.sharesync.android.sync.MediaType
import com.sharesync.android.transfer.server.MediaProvider
import java.time.Instant

class MediaStoreMediaScanner(
    private val contentResolver: ContentResolver,
    private val sourceDeviceId: String,
) : MediaScanner, MediaProvider {
    override suspend fun scanRecent(limit: Int): List<MediaAsset> {
        val safeLimit = limit.coerceIn(1, 500)
        return queryRecent(
            collection = MediaStore.Files.getContentUri("external"),
            limit = safeLimit,
        )
    }

    override suspend fun findMedia(assetId: String): MediaAsset? {
        val parsed = MediaStoreAssetId.parse(assetId) ?: return null
        return queryById(parsed)
    }

    fun contentUriFor(asset: MediaAsset): Uri? {
        return asset.contentUri?.let(Uri::parse)
    }

    private fun queryRecent(collection: Uri, limit: Int): List<MediaAsset> {
        val selection = "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (?, ?)"
        val selectionArgs = arrayOf(
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
        )

        val cursor = contentResolver.query(
            collection,
            projection,
            Bundle().apply {
                putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, selectionArgs)
                putStringArray(
                    ContentResolver.QUERY_ARG_SORT_COLUMNS,
                    arrayOf(MediaStore.Files.FileColumns.DATE_MODIFIED),
                )
                putInt(
                    ContentResolver.QUERY_ARG_SORT_DIRECTION,
                    ContentResolver.QUERY_SORT_DIRECTION_DESCENDING,
                )
                putInt(ContentResolver.QUERY_ARG_LIMIT, limit)
            },
            null,
        ) ?: return emptyList()

        return cursor.use {
            buildList {
                while (it.moveToNext()) {
                    rowToMediaAsset(it)?.let(::add)
                }
            }
        }
    }

    private fun queryById(parsed: MediaStoreAssetId): MediaAsset? {
        val collection = MediaStore.Files.getContentUri("external")
        val cursor = contentResolver.query(
            collection,
            projection,
            "${MediaStore.Files.FileColumns._ID} = ? AND ${MediaStore.Files.FileColumns.MEDIA_TYPE} = ?",
            arrayOf(parsed.id.toString(), parsed.mediaStoreType.toString()),
            null,
        ) ?: return null

        return cursor.use {
            if (it.moveToFirst()) rowToMediaAsset(it) else null
        }
    }

    private fun rowToMediaAsset(cursor: android.database.Cursor): MediaAsset? {
        val id = cursor.long(columnId)
        val mediaStoreType = cursor.int(columnMediaType)
        val mediaType = when (mediaStoreType) {
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE -> MediaType.photo
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO -> MediaType.video
            else -> return null
        }

        val mimeType = cursor.string(columnMimeType)
            ?: if (mediaType == MediaType.photo) "image/jpeg" else "video/mp4"
        val displayName = cursor.string(columnDisplayName) ?: "${mediaType.name}-$id"
        val contentUri = MediaStore.Files.getContentUri("external", id)

        return MediaAsset(
            assetId = MediaStoreAssetId(id = id, mediaStoreType = mediaStoreType).value,
            sourceDeviceId = sourceDeviceId,
            mediaType = mediaType,
            fileName = displayName,
            mimeType = mimeType,
            size = cursor.long(columnSize).coerceAtLeast(0),
            createdAt = cursor.secondsToIsoInstant(columnDateAdded),
            modifiedAt = cursor.secondsToIsoInstant(columnDateModified),
            takenAt = cursor.millisToIsoInstant(columnDateTaken),
            width = cursor.intOrNull(columnWidth),
            height = cursor.intOrNull(columnHeight),
            durationMs = cursor.longOrNull(columnDuration),
            relativePath = cursor.stringOrNull(columnRelativePath),
            contentUri = contentUri.toString(),
        )
    }

    private data class MediaStoreAssetId(
        val id: Long,
        val mediaStoreType: Int,
    ) {
        val value: String
            get() = "mediastore-$mediaStoreType-$id"

        companion object {
            fun parse(value: String): MediaStoreAssetId? {
                val parts = value.split("-")
                if (parts.size != 3 || parts[0] != "mediastore") return null
                val mediaStoreType = parts[1].toIntOrNull() ?: return null
                val id = parts[2].toLongOrNull() ?: return null
                return MediaStoreAssetId(id = id, mediaStoreType = mediaStoreType)
            }
        }
    }

    private companion object {
        val projection = buildList {
            add(MediaStore.Files.FileColumns._ID)
            add(MediaStore.Files.FileColumns.MEDIA_TYPE)
            add(MediaStore.Files.FileColumns.DISPLAY_NAME)
            add(MediaStore.Files.FileColumns.MIME_TYPE)
            add(MediaStore.Files.FileColumns.SIZE)
            add(MediaStore.Files.FileColumns.DATE_ADDED)
            add(MediaStore.Files.FileColumns.DATE_MODIFIED)
            add(MediaStore.Images.Media.DATE_TAKEN)
            add(MediaStore.MediaColumns.WIDTH)
            add(MediaStore.MediaColumns.HEIGHT)
            add(MediaStore.Video.Media.DURATION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                add(MediaStore.MediaColumns.RELATIVE_PATH)
            }
        }.toTypedArray()

        val columnId = projection.indexOf(MediaStore.Files.FileColumns._ID)
        val columnMediaType = projection.indexOf(MediaStore.Files.FileColumns.MEDIA_TYPE)
        val columnDisplayName = projection.indexOf(MediaStore.Files.FileColumns.DISPLAY_NAME)
        val columnMimeType = projection.indexOf(MediaStore.Files.FileColumns.MIME_TYPE)
        val columnSize = projection.indexOf(MediaStore.Files.FileColumns.SIZE)
        val columnDateAdded = projection.indexOf(MediaStore.Files.FileColumns.DATE_ADDED)
        val columnDateModified = projection.indexOf(MediaStore.Files.FileColumns.DATE_MODIFIED)
        val columnDateTaken = projection.indexOf(MediaStore.Images.Media.DATE_TAKEN)
        val columnWidth = projection.indexOf(MediaStore.MediaColumns.WIDTH)
        val columnHeight = projection.indexOf(MediaStore.MediaColumns.HEIGHT)
        val columnDuration = projection.indexOf(MediaStore.Video.Media.DURATION)
        val columnRelativePath = projection.indexOf(MediaStore.MediaColumns.RELATIVE_PATH)
    }
}

private fun android.database.Cursor.string(index: Int): String? {
    return if (index >= 0 && !isNull(index)) getString(index) else null
}

private fun android.database.Cursor.stringOrNull(index: Int): String? {
    return if (index >= 0 && !isNull(index)) getString(index) else null
}

private fun android.database.Cursor.int(index: Int): Int {
    return if (index >= 0 && !isNull(index)) getInt(index) else 0
}

private fun android.database.Cursor.intOrNull(index: Int): Int? {
    return if (index >= 0 && !isNull(index)) getInt(index) else null
}

private fun android.database.Cursor.long(index: Int): Long {
    return if (index >= 0 && !isNull(index)) getLong(index) else 0L
}

private fun android.database.Cursor.longOrNull(index: Int): Long? {
    return if (index >= 0 && !isNull(index)) getLong(index) else null
}

private fun android.database.Cursor.secondsToIsoInstant(index: Int): String? {
    val seconds = longOrNull(index) ?: return null
    if (seconds <= 0) return null
    return Instant.ofEpochSecond(seconds).toString()
}

private fun android.database.Cursor.millisToIsoInstant(index: Int): String? {
    val millis = longOrNull(index) ?: return null
    if (millis <= 0) return null
    return Instant.ofEpochMilli(millis).toString()
}
