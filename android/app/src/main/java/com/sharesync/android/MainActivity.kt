package com.sharesync.android

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.sharesync.android.pairing.PairingPayloadFactory
import com.sharesync.android.pairing.QrCodeBitmapFactory
import com.sharesync.android.security.DeviceIdentity
import com.sharesync.android.security.DeviceIdentityStore
import com.sharesync.android.security.SharedPreferencesDeviceIdentityStore
import com.sharesync.android.sync.ManifestBuilder
import com.sharesync.android.sync.ManifestJsonEncoder
import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncResult
import com.sharesync.android.sync.SyncResultStore
import com.sharesync.android.scanner.media.MediaStreamProvider
import com.sharesync.android.transfer.server.LocalServerBinder
import com.sharesync.android.transfer.server.LocalSyncRouter
import com.sharesync.android.transfer.server.LocalSyncServer
import java.net.BindException
import java.util.UUID

class MainActivity : Activity() {
    private lateinit var statusText: TextView
    private lateinit var endpointText: TextView
    private lateinit var permissionText: TextView
    private lateinit var manifestSummaryText: TextView
    private lateinit var syncResultText: TextView
    private lateinit var pairingPayloadText: TextView
    private lateinit var pairingQrImage: ImageView
    private lateinit var startButton: Button
    private lateinit var stopButton: Button
    private lateinit var copyPairingButton: Button

    private var server: LocalSyncServer? = null
    private var isServerRunning = false
    private var currentPairingPayloadJson: String? = null
    private var currentManifestPhotoCount: Int? = null
    private var currentSyncResult: SyncResult? = null
    private var syncResultStore: SyncResultStore? = null
    private var manifestBuilder: ManifestBuilder? = null
    private lateinit var deviceIdentityStore: DeviceIdentityStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        deviceIdentityStore = SharedPreferencesDeviceIdentityStore(this)
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

        val scrollView = ScrollView(this).apply {
            isFillViewport = true
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.TOP
            setPadding(padding, padding, padding, padding)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
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
        manifestSummaryText = bodyText(topPadding = 12 * density)
        syncResultText = bodyText(topPadding = 12 * density)
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
        root.addView(manifestSummaryText)
        root.addView(syncResultText)
        root.addView(pairingQrImage)
        root.addView(pairingPayloadText)
        root.addView(grantButton)
        root.addView(startButton)
        root.addView(stopButton)
        root.addView(copyPairingButton)
        scrollView.addView(root)
        setContentView(scrollView)
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
        val displayPort = server?.port ?: M0SyncComponents.defaultPort()
        val endpoint = if (ip == null) {
            getString(R.string.m0_endpoint_unavailable)
        } else {
            getString(R.string.m0_endpoint, ip, displayPort)
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
        manifestSummaryText.text = currentManifestPhotoCount?.let { count ->
            getString(R.string.m0_manifest_summary, count)
        } ?: getString(R.string.m0_manifest_unavailable)
        syncResultText.text = currentSyncResult?.let(::formatSyncResult)
            ?: getString(R.string.m0_sync_result_unavailable)
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
            listOf(Manifest.permission.READ_MEDIA_IMAGES)
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
                val identity = SuspendBridge.runBlocking {
                    deviceIdentityStore.getOrCreate()
                }
                val pairingToken = UUID.randomUUID().toString().replace("-", "")
                val components = M0SyncComponents.create(
                    context = this,
                    deviceId = identity.deviceId,
                    appVersion = "0.1.0",
                    pairingToken = pairingToken,
                )
                val createdServer = startLocalServer(
                    serverBinder = components.serverBinder,
                    router = components.router,
                    mediaStreamProvider = components.mediaStreamProvider,
                )
                server = createdServer
                syncResultStore = components.syncResultStore
                manifestBuilder = components.manifestBuilder
                currentSyncResult = SuspendBridge.runBlocking { components.syncResultStore.latest() }
                currentManifestPhotoCount = SuspendBridge.runBlocking {
                    components.manifestBuilder.buildM0Manifest().media.size
                }
                isServerRunning = true
                currentPairingPayloadJson = createPairingPayloadJson(
                    identity = identity,
                    port = createdServer.port,
                    pairingToken = pairingToken,
                )
                runOnUiThread { refreshUi() }
                pollSyncResultUpdates(components.syncResultStore)
            } catch (error: Throwable) {
                server = null
                syncResultStore = null
                manifestBuilder = null
                currentManifestPhotoCount = null
                isServerRunning = false
                currentPairingPayloadJson = null
                runOnUiThread {
                    refreshUi(getString(R.string.m0_status_failed, error.message ?: "unknown error"))
                }
            }
        }.start()
    }

    private fun startLocalServer(
        serverBinder: LocalServerBinder,
        router: LocalSyncRouter,
        mediaStreamProvider: MediaStreamProvider,
    ): LocalSyncServer {
        return try {
            bindAndStartServer(
                serverBinder = serverBinder,
                router = router,
                mediaStreamProvider = mediaStreamProvider,
                port = M0SyncComponents.defaultPort(),
            )
        } catch (error: BindException) {
            bindAndStartServer(
                serverBinder = serverBinder,
                router = router,
                mediaStreamProvider = mediaStreamProvider,
                port = AVAILABLE_PORT,
            )
        }
    }

    private fun bindAndStartServer(
        serverBinder: LocalServerBinder,
        router: LocalSyncRouter,
        mediaStreamProvider: MediaStreamProvider,
        port: Int,
    ): LocalSyncServer {
        val createdServer = SuspendBridge.runBlocking {
            serverBinder.bind(
                router = router,
                mediaStreamProvider = mediaStreamProvider,
                port = port,
            )
        }
        SuspendBridge.runBlocking { createdServer.start() }
        return createdServer
    }

    private fun stopServer() {
        val currentServer = server ?: return
        server = null
        syncResultStore = null
        manifestBuilder = null
        currentManifestPhotoCount = null
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

    private fun createPairingPayloadJson(
        identity: DeviceIdentity,
        port: Int,
        pairingToken: String,
    ): String? {
        val ip = LocalNetworkAddresses.firstIpv4Address() ?: return null
        val payload = PairingPayloadFactory(
            deviceIdProvider = { identity.deviceId },
            deviceNameProvider = { identity.deviceName },
            publicKeyProvider = { identity.publicKey },
            localIpProvider = { ip },
            portProvider = { port },
            pairingTokenProvider = { pairingToken },
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

    private fun pollSyncResultUpdates(store: SyncResultStore) {
        Thread {
            repeat(SYNC_RESULT_POLL_COUNT) {
                Thread.sleep(SYNC_RESULT_POLL_INTERVAL_MS)
                if (!isServerRunning) {
                    return@Thread
                }
                currentSyncResult = SuspendBridge.runBlocking { store.latest() }
                currentManifestPhotoCount = manifestBuilder?.let { builder ->
                    SuspendBridge.runBlocking { builder.buildM0Manifest().media.size }
                }
                runOnUiThread { refreshUi() }
            }
        }.start()
    }

    private fun formatSyncResult(result: SyncResult): String {
        val syncedCount = result.results.count { it.status == SyncItemStatus.synced }
        val skippedCount = result.results.count { it.status == SyncItemStatus.skipped }
        val failedCount = result.results.count { it.status == SyncItemStatus.failed }
        val latestFailureCode = result.results
            .lastOrNull { it.status == SyncItemStatus.failed }
            ?.errorCode
            ?: getString(R.string.m0_sync_result_no_failure)
        return getString(
            R.string.m0_sync_result_summary,
            result.syncBatchId,
            syncedCount,
            skippedCount,
            failedCount,
            latestFailureCode,
        )
    }

    private companion object {
        const val REQUEST_MEDIA_PERMISSION = 1001
        const val AVAILABLE_PORT = 0
        const val SYNC_RESULT_POLL_COUNT = 30
        const val SYNC_RESULT_POLL_INTERVAL_MS = 2_000L
    }
}
