package com.sharesync.android.pairing

import android.graphics.Bitmap
import android.graphics.Matrix
import com.google.zxing.BinaryBitmap
import com.google.zxing.MultiFormatReader
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer

class QrCodeBitmapDecoder {
    fun decode(bitmap: Bitmap): String {
        var candidate = bitmap
        repeat(4) { rotation ->
            runCatching { return decodeOrientation(candidate) }
            if (rotation < 3) {
                candidate = Bitmap.createBitmap(
                    candidate,
                    0,
                    0,
                    candidate.width,
                    candidate.height,
                    Matrix().apply { postRotate(90f) },
                    true,
                )
            }
        }
        error("No QR code found")
    }

    private fun decodeOrientation(bitmap: Bitmap): String {
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        val source = RGBLuminanceSource(bitmap.width, bitmap.height, pixels)
        return MultiFormatReader().decode(BinaryBitmap(HybridBinarizer(source))).text
    }
}
