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
import android.view.WindowManager
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
import com.sharesync.android.sync.FileSyncResultStore
import com.sharesync.android.sync.ManifestBuilder
import com.sharesync.android.sync.ManifestJsonEncoder
import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncResult
import com.sharesync.android.sync.SyncResultJsonCodec
import com.sharesync.android.sync.SyncResultStore
import com.sharesync.android.scanner.media.MediaStreamProvider
import com.sharesync.android.transfer.server.LocalServerBinder
import com.sharesync.android.transfer.server.LocalSyncRouter
import com.sharesync.android.transfer.server.LocalSyncServer
import java.net.BindException
import java.util.UUID

class MainActivity : Activity() {
    private lateinit var statusText: TextView
    private lateinit var phaseText: TextView
    private lateinit var endpointText: TextView
    private lateinit var permissionText: TextView
    private lateinit var screenLockText: TextView
    private lateinit var manifestSummaryText: TextView
    private lateinit var syncResultText: TextView
    private lateinit var pairingPayloadText: TextView
    private lateinit var pairingQrImage: ImageView
    private lateinit var startButton: Button
    private lateinit var stopButton: Button
    private lateinit var copyEndpointButton: Button
    private lateinit var copyPairingButton: Button
    private lateinit var copySyncResultButton: Button
    private lateinit var clearSyncStateButton: Button

    private var server: LocalSyncServer? = null
    @Volatile
    private var isServerRunning = false
    @Volatile
    private var isServerStarting = false
    @Volatile
    private var syncResultPollThread: Thread? = null
    private var currentPairingPayloadJson: String? = null
    private var currentManifestPhotoCount: Int? = null
    private var currentSyncResult: SyncResult? = null
    private var syncResultStore: SyncResultStore? = null
    private var manifestBuilder: ManifestBuilder? = null
    private lateinit var deviceIdentityStore: DeviceIdentityStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        deviceIdentityStore = SharedPreferencesDeviceIdentityStore(this)
        restorePersistedSyncResult()
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
        phaseText = bodyText(topPadding = 12 * density)
        endpointText = bodyText(topPadding = 12 * density)
        permissionText = bodyText(topPadding = 12 * density)
        screenLockText = bodyText(topPadding = 12 * density)
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

        copyEndpointButton = Button(this).apply {
            text = getString(R.string.m0_copy_endpoint)
            setOnClickListener { copyEndpoint() }
        }

        copyPairingButton = Button(this).apply {
            text = getString(R.string.m0_copy_pairing_payload)
            setOnClickListener { copyPairingPayload() }
        }

        copySyncResultButton = Button(this).apply {
            text = getString(R.string.m0_copy_sync_result)
            setOnClickListener { copySyncResult() }
        }

        clearSyncStateButton = Button(this).apply {
            text = getString(R.string.m0_clear_sync_state)
            setOnClickListener { clearSyncState() }
        }

        root.addView(title)
        root.addView(statusText)
        root.addView(phaseText)
        root.addView(endpointText)
        root.addView(permissionText)
        root.addView(screenLockText)
        root.addView(manifestSummaryText)
        root.addView(syncResultText)
        root.addView(pairingQrImage)
        root.addView(pairingPayloadText)
        root.addView(grantButton)
        root.addView(startButton)
        root.addView(stopButton)
        root.addView(copyEndpointButton)
        root.addView(copyPairingButton)
        root.addView(copySyncResultButton)
        root.addView(clearSyncStateButton)
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
        val endpointUrl = currentEndpointUrl()
        val endpoint = endpointUrl?.let { getString(R.string.m0_endpoint, it) }
            ?: getString(R.string.m0_endpoint_unavailable)

        val status = when {
            message != null -> message
            isServerRunning -> getString(R.string.m0_status_running)
            else -> getString(R.string.m0_status_ready, M0SyncComponents.defaultPort())
        }

        statusText.text = status
        phaseText.text = getString(R.string.m0_phase, phaseStatus())
        endpointText.text = endpoint
        permissionText.text = if (hasMediaPermission()) {
            getString(R.string.m0_permission_granted)
        } else {
            getString(R.string.m0_permission_missing)
        }
        screenLockText.text = if (isServerRunning) {
            getString(R.string.m0_screen_lock_paused)
        } else {
            getString(R.string.m0_screen_lock_normal)
        }
        pairingPayloadText.text = currentPairingPayloadJson
            ?: getString(R.string.m0_pairing_payload_unavailable)
        manifestSummaryText.text = currentManifestPhotoCount?.let { count ->
            getString(R.string.m0_manifest_summary, count, manifestTransferStatus(count))
        } ?: getString(R.string.m0_manifest_unavailable)
        syncResultText.text = currentSyncResult?.let(::formatSyncResult)
            ?: getString(R.string.m0_sync_result_unavailable)
        refreshPairingQr()

        startButton.isEnabled = !isServerRunning && hasMediaPermission()
        stopButton.isEnabled = isServerRunning
        copyEndpointButton.isEnabled = endpointUrl != null
        copyPairingButton.isEnabled = currentPairingPayloadJson != null
        copySyncResultButton.isEnabled = currentSyncResult != null
        clearSyncStateButton.isEnabled = currentSyncResult != null
        updateKeepScreenAwake()
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
        isServerStarting = true
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
                isServerStarting = false
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
                restorePersistedSyncResult()
                manifestBuilder = null
                currentManifestPhotoCount = null
                isServerStarting = false
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
        manifestBuilder = null
        currentManifestPhotoCount = null
        isServerStarting = false
        isServerRunning = false
        currentPairingPayloadJson = null
        restorePersistedSyncResult()
        syncResultPollThread?.interrupt()
        syncResultPollThread = null
        updateKeepScreenAwake()

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
        copyText(label = "ShareSync pairing payload", text = payload)
        refreshUi(getString(R.string.m0_pairing_payload_copied))
    }

    private fun copyEndpoint() {
        val endpointUrl = currentEndpointUrl() ?: return
        copyText(label = "ShareSync health endpoint", text = endpointUrl)
        refreshUi(getString(R.string.m0_endpoint_copied))
    }

    private fun copySyncResult() {
        val result = currentSyncResult ?: return
        val json = SyncResultJsonCodec().encode(result)
        copyText(label = "ShareSync sync result", text = json)
        refreshUi(getString(R.string.m0_sync_result_copied))
    }

    private fun copyText(label: String, text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText(label, text))
    }

    private fun clearSyncState() {
        val store = syncResultStore ?: return
        Thread {
            SuspendBridge.runBlocking { store.clear() }
            currentSyncResult = null
            currentManifestPhotoCount = manifestBuilder?.let { builder ->
                SuspendBridge.runBlocking { builder.buildM0Manifest().media.size }
            }
            runOnUiThread { refreshUi(getString(R.string.m0_sync_state_cleared)) }
        }.start()
    }

    private fun restorePersistedSyncResult() {
        val store = FileSyncResultStore(
            file = FileSyncResultStore.defaultFile(applicationContext.filesDir),
        )
        syncResultStore = store
        currentSyncResult = SuspendBridge.runBlocking { store.latest() }
    }

    private fun currentEndpointUrl(): String? {
        val ip = LocalNetworkAddresses.firstIpv4Address() ?: return null
        val displayPort = server?.port ?: M0SyncComponents.defaultPort()
        return "http://$ip:$displayPort/v1/health"
    }

    private fun updateKeepScreenAwake() {
        if (isServerRunning) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    private fun pollSyncResultUpdates(store: SyncResultStore) {
        if (syncResultPollThread?.isAlive == true) {
            return
        }

        syncResultPollThread = Thread {
            while (isServerRunning) {
                try {
                    Thread.sleep(SYNC_RESULT_POLL_INTERVAL_MS)
                } catch (_: InterruptedException) {
                    return@Thread
                }

                if (!isServerRunning) {
                    return@Thread
                }
                currentSyncResult = SuspendBridge.runBlocking { store.latest() }
                currentManifestPhotoCount = manifestBuilder?.let { builder ->
                    SuspendBridge.runBlocking { builder.buildM0Manifest().media.size }
                }
                runOnUiThread { refreshUi() }
            }
        }.also { thread ->
            thread.start()
        }
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

    private fun runtimeState(): AndroidM0RuntimeState {
        return AndroidM0RuntimeState(
            hasMediaPermission = hasMediaPermission(),
            isServerStarting = isServerStarting,
            isServerRunning = isServerRunning,
            pendingPhotoCount = currentManifestPhotoCount,
            latestSyncResult = currentSyncResult,
        )
    }

    private fun phaseStatus(): String {
        return when (runtimeState().phase()) {
            AndroidM0Phase.PERMISSION_REQUIRED -> getString(R.string.m0_phase_permission_required)
            AndroidM0Phase.READY_TO_START -> getString(R.string.m0_phase_ready_to_start)
            AndroidM0Phase.SERVER_STARTING -> getString(R.string.m0_phase_server_starting)
            AndroidM0Phase.READY_TO_PAIR -> getString(R.string.m0_phase_ready_to_pair)
            AndroidM0Phase.RETRY_REQUIRED -> getString(R.string.m0_phase_retry_required)
            AndroidM0Phase.TRANSFER_COMPLETE -> getString(R.string.m0_phase_transfer_complete)
        }
    }

    private fun manifestTransferStatus(pendingPhotoCount: Int): String {
        val state = runtimeState().copy(pendingPhotoCount = pendingPhotoCount)
        return when (state.manifestStatus()) {
            AndroidM0ManifestStatus.COMPLETE -> getString(R.string.m0_manifest_status_complete)
            AndroidM0ManifestStatus.NEEDS_RETRY -> getString(R.string.m0_manifest_status_needs_retry)
            AndroidM0ManifestStatus.READY,
            null,
            -> getString(R.string.m0_manifest_status_ready)
        }
    }

    private companion object {
        const val REQUEST_MEDIA_PERMISSION = 1001
        const val AVAILABLE_PORT = 0
        const val SYNC_RESULT_POLL_INTERVAL_MS = 2_000L
    }
}
