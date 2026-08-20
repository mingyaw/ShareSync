package com.sharesync.android.scanner.media

import android.content.ContentResolver
import android.net.Uri
import java.io.InputStream

class MediaStreamProvider(
    private val contentResolver: ContentResolver,
) {
    fun open(contentUri: String): InputStream? {
        return contentResolver.openInputStream(Uri.parse(contentUri))
    }
}

