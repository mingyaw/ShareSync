package com.sharesync.android.scanner.media

import android.content.ContentResolver
import android.net.Uri
import java.io.InputStream
import java.security.MessageDigest

class MediaStreamProvider(
    private val contentResolver: ContentResolver,
) {
    fun open(contentUri: String): InputStream? {
        return contentResolver.openInputStream(Uri.parse(contentUri))
    }

    fun sha256(contentUri: String): String? {
        val stream = open(contentUri) ?: return null
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)

        stream.use { input ->
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }

        return digest.digest().joinToString(separator = "") { byte ->
            "%02x".format(byte)
        }
    }
}
