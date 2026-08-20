package com.sharesync.android

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.sharesync.android.pairing.PairingPayloadFactory
import com.sharesync.android.pairing.QrCodeBitmapFactory
import com.sharesync.android.sync.ManifestJsonEncoder
import com.sharesync.android.transfer.server.LocalSyncServer

class MainActivity : Activity() {
    private lateinit var statusText: TextView
    private lateinit var endpointText: TextView
    private lateinit var permissionText: TextView
    private lateinit var pairingPayloadText: TextView
    private lateinit var pairingQrImage: ImageView
    private lateinit var startButton: Button
    private lateinit var stopButton: Button
    private lateinit var copyPairingButton: Button

    private var server: LocalSyncServer? = null
    private var isServerRunning = false
    private var currentPairingPayloadJson: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        renderContent()
        refreshUi()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopServer()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_MEDIA_PERMISSION) {
            refreshUi()
        }
    }

    private fun renderContent() {
        val density = resources.displayMetrics.density
        val padding = (24 * density).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(padding, padding, padding, padding)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        val title = TextView(this).apply {
            text = getString(R.string.app_name)
            textSize = 28f
            setTextColor(getColor(android.R.color.black))
        }

        statusText = bodyText(topPadding = 12 * density)
        endpointText = bodyText(topPadding = 12 * density)
        permissionText = bodyText(topPadding = 12 * density)
        pairingPayloadText = bodyText(topPadding = 12 * density)
        pairingQrImage = ImageView(this).apply {
            adjustViewBounds = true
            setBackgroundColor(getColor(android.R.color.white))
            setPadding(8, 8, 8, 8)
            visibility = ImageView.GONE
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = (16 * density).toInt()
            }
        }

        val grantButton = Button(this).apply {
            text = getString(R.string.m0_grant_permission)
            setOnClickListener { requestMediaPermission() }
        }

        startButton = Button(this).apply {
            text = getString(R.string.m0_start_server)
            setOnClickListener { startServer() }
        }

        stopButton = Button(this).apply {
            text = getString(R.string.m0_stop_server)
            setOnClickListener { stopServer() }
        }

        copyPairingButton = Button(this).apply {
            text = getString(R.string.m0_copy_pairing_payload)
            setOnClickListener { copyPairingPayload() }
        }

        root.addView(title)
        root.addView(statusText)
        root.addView(endpointText)
        root.addView(permissionText)
        root.addView(pairingQrImage)
        root.addView(pairingPayloadText)
        root.addView(grantButton)
        root.addView(startButton)
        root.addView(stopButton)
        root.addView(copyPairingButton)
        setContentView(root)
    }

    private fun bodyText(topPadding: Float): TextView {
        return TextView(this).apply {
            textSize = 16f
            setTextColor(getColor(android.R.color.darker_gray))
            setPadding(0, topPadding.toInt(), 0, 0)
        }
    }

    private fun refreshUi(message: String? = null) {
        val ip = LocalNetworkAddresses.firstIpv4Address()
        val endpoint = if (ip == null) {
            getString(R.string.m0_endpoint_unavailable)
        } else {
            getString(R.string.m0_endpoint, ip, M0SyncComponents.defaultPort())
        }

        val status = when {
            message != null -> message
            isServerRunning -> getString(R.string.m0_status_running)
            else -> getString(R.string.m0_status_ready, M0SyncComponents.defaultPort())
        }

        statusText.text = status
        endpointText.text = endpoint
        permissionText.text = if (hasMediaPermission()) {
            getString(R.string.m0_permission_granted)
        } else {
            getString(R.string.m0_permission_missing)
        }
        pairingPayloadText.text = currentPairingPayloadJson
            ?: getString(R.string.m0_pairing_payload_unavailable)
        refreshPairingQr()

        startButton.isEnabled = !isServerRunning && hasMediaPermission()
        stopButton.isEnabled = isServerRunning
        copyPairingButton.isEnabled = currentPairingPayloadJson != null
    }

    private fun requestMediaPermission() {
        val missing = requiredMediaPermissions()
            .filter { permission -> checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED }
            .toTypedArray()

        if (missing.isEmpty()) {
            refreshUi()
            return
        }

        requestPermissions(missing, REQUEST_MEDIA_PERMISSION)
    }

    private fun hasMediaPermission(): Boolean {
        return requiredMediaPermissions().all { permission ->
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requiredMediaPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            listOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
            )
        } else {
            listOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
    }

    private fun startServer() {
        if (!hasMediaPermission()) {
            requestMediaPermission()
            return
        }

        startButton.isEnabled = false
        refreshUi(getString(R.string.m0_status_starting))

        Thread {
            try {
                val components = M0SyncComponents.create(
                    context = this,
                    deviceId = deviceId(),
                    appVersion = "0.1.0",
                )
                val createdServer = SuspendBridge.runBlocking {
                    components.serverBinder.bind(
                        router = components.router,
                        mediaStreamProvider = components.mediaStreamProvider,
                        port = M0SyncComponents.defaultPort(),
                    )
                }
                SuspendBridge.runBlocking { createdServer.start() }
                server = createdServer
                isServerRunning = true
                currentPairingPayloadJson = createPairingPayloadJson()
                runOnUiThread { refreshUi() }
            } catch (error: Throwable) {
                server = null
                isServerRunning = false
                currentPairingPayloadJson = null
                runOnUiThread {
                    refreshUi(getString(R.string.m0_status_failed, error.message ?: "unknown error"))
                }
            }
        }.start()
    }

    private fun stopServer() {
        val currentServer = server ?: return
        server = null
        isServerRunning = false
        currentPairingPayloadJson = null

        Thread {
            try {
                SuspendBridge.runBlocking { currentServer.stop() }
            } finally {
                runOnUiThread { refreshUi() }
            }
        }.start()
    }

    private fun deviceId(): String {
        return Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
            ?: "android-device"
    }

    private fun createPairingPayloadJson(): String? {
        val ip = LocalNetworkAddresses.firstIpv4Address() ?: return null
        val payload = PairingPayloadFactory(
            deviceIdProvider = ::deviceId,
            deviceNameProvider = { Build.MODEL ?: "Android" },
            publicKeyProvider = { "m0-public-key-placeholder" },
            localIpProvider = { ip },
            portProvider = { M0SyncComponents.defaultPort() },
        ).createPayload()
        return ManifestJsonEncoder().encode(payload)
    }

    private fun refreshPairingQr() {
        val payload = currentPairingPayloadJson
        if (payload == null) {
            pairingQrImage.setImageDrawable(null)
            pairingQrImage.visibility = ImageView.GONE
            return
        }

        val size = (resources.displayMetrics.widthPixels - (64 * resources.displayMetrics.density)).toInt()
            .coerceAtLeast((220 * resources.displayMetrics.density).toInt())
        pairingQrImage.setImageBitmap(QrCodeBitmapFactory().create(payload, size))
        pairingQrImage.visibility = ImageView.VISIBLE
    }

    private fun copyPairingPayload() {
        val payload = currentPairingPayloadJson ?: return
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("ShareSync pairing payload", payload))
        refreshUi(getString(R.string.m0_pairing_payload_copied))
    }

    private companion object {
        const val REQUEST_MEDIA_PERMISSION = 1001
    }
}
