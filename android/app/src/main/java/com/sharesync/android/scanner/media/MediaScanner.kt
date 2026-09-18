package com.sharesync.android.scanner.media

import com.sharesync.android.sync.MediaAsset

interface MediaScanner {
    suspend fun scanRecent(
        limit: Int = 100,
        offset: Int = 0,
        modifiedAfter: MediaScanCursor? = null,
        modifiedAtOrBefore: MediaScanCursor? = null,
    ): List<MediaAsset>
}

data class MediaScanCursor(
    val modifiedAtEpochSeconds: Long,
    val mediaStoreId: Long,
)

class MediaScannerStub : MediaScanner {
    override suspend fun scanRecent(
        limit: Int,
        offset: Int,
        modifiedAfter: MediaScanCursor?,
        modifiedAtOrBefore: MediaScanCursor?,
    ): List<MediaAsset> {
        return emptyList()
    }
}
