package com.sharesync.android

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.LuminanceSource
import com.google.zxing.MultiFormatReader
import com.google.zxing.PlanarYUVLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.sharesync.android.pairing.MacPairingOfferParser
import com.sharesync.android.ui.ShareSyncComposeTheme
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MacQrScannerActivity : ComponentActivity() {
    private val analysisExecutor = Executors.newSingleThreadExecutor()
    private val resultDelivered = AtomicBoolean(false)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            ShareSyncComposeTheme {
                MacQrScannerScreen(
                    onClose = { finish() },
                    onPreviewReady = ::bindCamera,
                )
            }
        }
    }

    override fun onDestroy() {
        analysisExecutor.shutdown()
        super.onDestroy()
    }

    private fun bindCamera(previewView: PreviewView) {
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener({
            if (isFinishing || isDestroyed) return@addListener
            val provider = providerFuture.get()
            val preview = Preview.Builder().build().also {
                it.surfaceProvider = previewView.surfaceProvider
            }
            val analysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also { useCase ->
                    useCase.setAnalyzer(analysisExecutor, QrFrameAnalyzer(::deliverResult))
                }
            provider.unbindAll()
            provider.bindToLifecycle(
                this,
                CameraSelector.DEFAULT_BACK_CAMERA,
                preview,
                analysis,
            )
        }, ContextCompat.getMainExecutor(this))
    }

    private fun deliverResult(payload: String) {
        if (runCatching { MacPairingOfferParser().parse(payload) }.isFailure) return
        if (!resultDelivered.compareAndSet(false, true)) return
        runOnUiThread {
            setResult(
                Activity.RESULT_OK,
                Intent().putExtra(EXTRA_QR_PAYLOAD, payload),
            )
            finish()
        }
    }

    companion object {
        const val EXTRA_QR_PAYLOAD = "com.sharesync.android.extra.MAC_PAIRING_QR"
    }
}

@Composable
private fun MacQrScannerScreen(
    onClose: () -> Unit,
    onPreviewReady: (PreviewView) -> Unit,
) {
    val context = LocalContext.current
    val previewView = remember {
        PreviewView(context).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
    }
    DisposableEffect(previewView) {
        onPreviewReady(previewView)
        onDispose { }
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        AndroidView(
            factory = { previewView },
            modifier = Modifier.fillMaxSize(),
        )
        ScannerOverlay(modifier = Modifier.fillMaxSize())
        IconButton(
            onClick = onClose,
            modifier = Modifier
                .align(Alignment.TopStart)
                .statusBarsPadding()
                .padding(12.dp)
                .size(48.dp)
                .background(Color.Black.copy(alpha = 0.58f), MaterialTheme.shapes.small),
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_action_close),
                contentDescription = stringResource(R.string.mac_scanner_close),
                tint = Color.White,
            )
        }
        Column(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(horizontal = 28.dp, vertical = 36.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = stringResource(R.string.mac_scanner_title),
                style = MaterialTheme.typography.titleLarge,
                color = Color.White,
            )
            Spacer(modifier = Modifier.size(8.dp))
            Text(
                text = stringResource(R.string.mac_scanner_instruction),
                style = MaterialTheme.typography.bodyMedium,
                color = Color.White.copy(alpha = 0.84f),
            )
        }
    }
}

@Composable
private fun ScannerOverlay(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        val frameSize = size.minDimension * 0.66f
        val frame = Rect(
            left = (size.width - frameSize) / 2f,
            top = (size.height - frameSize) / 2f - size.height * 0.06f,
            right = (size.width + frameSize) / 2f,
            bottom = (size.height + frameSize) / 2f - size.height * 0.06f,
        )
        val shade = Color.Black.copy(alpha = 0.54f)
        drawRect(shade, size = androidx.compose.ui.geometry.Size(size.width, frame.top))
        drawRect(shade, topLeft = Offset(0f, frame.bottom), size = androidx.compose.ui.geometry.Size(size.width, size.height - frame.bottom))
        drawRect(shade, topLeft = Offset(0f, frame.top), size = androidx.compose.ui.geometry.Size(frame.left, frame.height))
        drawRect(shade, topLeft = Offset(frame.right, frame.top), size = androidx.compose.ui.geometry.Size(size.width - frame.right, frame.height))
        drawRoundRect(
            color = Color.White.copy(alpha = 0.92f),
            topLeft = frame.topLeft,
            size = frame.size,
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(18.dp.toPx()),
            style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round),
        )
    }
}

private class QrFrameAnalyzer(
    private val onDecoded: (String) -> Unit,
) : ImageAnalysis.Analyzer {
    private val reader = MultiFormatReader().apply {
        setHints(
            mapOf(
                DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE),
                DecodeHintType.TRY_HARDER to true,
                DecodeHintType.ALSO_INVERTED to true,
            ),
        )
    }

    override fun analyze(image: ImageProxy) {
        try {
            val source = image.toLuminanceSource()
            var candidate: LuminanceSource = source
            repeat(4) { rotation ->
                val decoded = runCatching {
                    reader.decodeWithState(BinaryBitmap(HybridBinarizer(candidate))).text
                }.getOrNull()
                reader.reset()
                if (!decoded.isNullOrBlank()) {
                    onDecoded(decoded)
                    return
                }
                if (rotation < 3 && candidate.isRotateSupported) {
                    candidate = candidate.rotateCounterClockwise()
                }
            }
        } finally {
            image.close()
        }
    }

    private fun ImageProxy.toLuminanceSource(): PlanarYUVLuminanceSource {
        val plane = planes.first()
        val buffer = plane.buffer
        val bytes = ByteArray(width * height)
        var output = 0
        for (row in 0 until height) {
            val rowStart = row * plane.rowStride
            for (column in 0 until width) {
                bytes[output++] = buffer.get(rowStart + column * plane.pixelStride)
            }
        }
        return PlanarYUVLuminanceSource(
            bytes,
            width,
            height,
            0,
            0,
            width,
            height,
            false,
        )
    }
}
