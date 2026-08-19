package com.sharesync.android.scanner.media

import com.sharesync.android.sync.MediaAsset

interface MediaScanner {
    suspend fun scanRecent(limit: Int = 100): List<MediaAsset>
}

class MediaScannerStub : MediaScanner {
    override suspend fun scanRecent(limit: Int): List<MediaAsset> {
        return emptyList()
    }
}

