package com.sharesync.android

import android.Manifest
import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.sharesync.android.pairing.QrCodeBitmapFactory
import com.sharesync.android.security.DeviceIdentityStore
import com.sharesync.android.security.SharedPreferencesDeviceIdentityStore
import com.sharesync.android.sync.FileSyncResultStore
import com.sharesync.android.sync.ManifestBuilder
import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncResult
import com.sharesync.android.sync.SyncResultJsonCodec
import com.sharesync.android.sync.SyncResultStore
import com.sharesync.android.transfer.server.LocalRequestActivity
import com.sharesync.android.transfer.server.LocalRequestActivityTracker
import com.sharesync.android.transfer.server.LocalSyncServer

class MainActivity : Activity() {
    private lateinit var statusText: TextView
    private lateinit var phaseText: TextView
    private lateinit var endpointText: TextView
    private lateinit var permissionText: TextView
    private lateinit var notificationPermissionText: TextView
    private lateinit var screenLockText: TextView
    private lateinit var manifestSummaryText: TextView
    private lateinit var requestActivityText: TextView
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
    private var currentRequestActivity: LocalRequestActivity? = null
    private var syncResultStore: SyncResultStore? = null
    private var manifestBuilder: ManifestBuilder? = null
    private var requestActivityTracker: LocalRequestActivityTracker? = null
    private lateinit var deviceIdentityStore: DeviceIdentityStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        deviceIdentityStore = SharedPreferencesDeviceIdentityStore(this)
        restorePersistedSyncResult()
        restoreRunningServerSession()
        renderContent()
        refreshUi()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing) {
            stopServer()
        } else {
            syncResultPollThread?.interrupt()
            syncResultPollThread = null
            updateKeepScreenAwake()
        }
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
        val padding = (20 * density).toInt()

        val scrollView = ScrollView(this).apply {
            isFillViewport = true
            setBackgroundColor(Color.rgb(242, 242, 247))
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
            typeface = Typeface.DEFAULT_BOLD
        }
        val subtitle = TextView(this).apply {
            text = getString(R.string.m0_android_subtitle)
            textSize = 15f
            setTextColor(Color.rgb(99, 99, 102))
            setPadding(0, (4 * density).toInt(), 0, (18 * density).toInt())
        }

        statusText = bodyText()
        phaseText = bodyText()
        endpointText = bodyText()
        permissionText = bodyText()
        notificationPermissionText = bodyText()
        screenLockText = bodyText()
        manifestSummaryText = bodyText()
        requestActivityText = bodyText()
        syncResultText = bodyText()
        pairingPayloadText = bodyText()
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
            text = getString(R.string.m0_grant_permissions)
            setOnClickListener { requestM0Permissions() }
            fullWidthButtonLayout()
        }

        startButton = Button(this).apply {
            text = getString(R.string.m0_start_server)
            setOnClickListener { startServer() }
            fullWidthButtonLayout()
        }

        stopButton = Button(this).apply {
            text = getString(R.string.m0_stop_server)
            setOnClickListener { stopServer() }
            fullWidthButtonLayout()
        }

        copyEndpointButton = Button(this).apply {
            text = getString(R.string.m0_copy_endpoint)
            setOnClickListener { copyEndpoint() }
            fullWidthButtonLayout()
        }

        copyPairingButton = Button(this).apply {
            text = getString(R.string.m0_copy_pairing_payload)
            setOnClickListener { copyPairingPayload() }
            fullWidthButtonLayout()
        }

        copySyncResultButton = Button(this).apply {
            text = getString(R.string.m0_copy_sync_result)
            setOnClickListener { copySyncResult() }
            fullWidthButtonLayout()
        }

        clearSyncStateButton = Button(this).apply {
            text = getString(R.string.m0_clear_sync_state)
            setOnClickListener { clearSyncState() }
            fullWidthButtonLayout()
        }

        root.addView(title)
        root.addView(subtitle)
        root.addView(
            productPanel(
                title = getString(R.string.m0_panel_summary),
                children = listOf(statusText, phaseText, manifestSummaryText, syncResultText),
            ),
        )
        root.addView(
            productPanel(
                title = getString(R.string.m0_panel_actions),
                children = listOf(grantButton, startButton, stopButton),
            ),
        )
        root.addView(
            productPanel(
                title = getString(R.string.m0_panel_pairing),
                children = listOf(endpointText, pairingQrImage, pairingPayloadText, copyPairingButton),
            ),
        )
        root.addView(
            productPanel(
                title = getString(R.string.m0_panel_diagnostics),
                children = listOf(
                    permissionText,
                    notificationPermissionText,
                    screenLockText,
                    requestActivityText,
                    copyEndpointButton,
                    copySyncResultButton,
                    clearSyncStateButton,
                ),
            ),
        )
        scrollView.addView(root)
        setContentView(scrollView)
    }

    private fun bodyText(): TextView {
        return TextView(this).apply {
            textSize = 16f
            setTextColor(Color.rgb(99, 99, 102))
            setPadding(0, (8 * resources.displayMetrics.density).toInt(), 0, 0)
        }
    }

    private fun productPanel(title: String, children: List<android.view.View>): LinearLayout {
        val density = resources.displayMetrics.density
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(
                (16 * density).toInt(),
                (14 * density).toInt(),
                (16 * density).toInt(),
                (16 * density).toInt(),
            )
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = 8 * density
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = (14 * density).toInt()
            }

            addView(TextView(context).apply {
                text = title
                textSize = 18f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.rgb(28, 28, 30))
                setPadding(0, 0, 0, (4 * density).toInt())
            })
            children.forEach(::addView)
        }
    }

    private fun Button.fullWidthButtonLayout() {
        val density = resources.displayMetrics.density
        minHeight = (48 * density).toInt()
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply {
            topMargin = (10 * density).toInt()
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
        notificationPermissionText.text = if (hasNotificationPermission()) {
            getString(R.string.m0_notification_permission_granted)
        } else {
            getString(R.string.m0_notification_permission_missing)
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
        requestActivityText.text = currentRequestActivity?.let(::formatRequestActivity)
            ?: getString(R.string.m0_request_activity_unavailable)
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

    private fun requestM0Permissions() {
        val missing = requiredM0Permissions()
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

    private fun hasNotificationPermission(): Boolean {
        return requiredNotificationPermissions().all { permission ->
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requiredNotificationPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            listOf(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            emptyList()
        }
    }

    private fun requiredM0Permissions(): List<String> {
        return requiredMediaPermissions() + requiredNotificationPermissions()
    }

    private fun startServer() {
        if (!hasMediaPermission()) {
            requestM0Permissions()
            return
        }

        startButton.isEnabled = false
        isServerStarting = true
        refreshUi(getString(R.string.m0_status_starting))

        Thread {
            try {
                val session = AndroidM0ServerSessionController.start(
                    context = applicationContext,
                    deviceIdentityStore = deviceIdentityStore,
                    appVersion = "0.1.0",
                )
                server = session.server
                syncResultStore = session.syncResultStore
                manifestBuilder = session.manifestBuilder
                requestActivityTracker = session.requestActivityTracker
                currentSyncResult = SuspendBridge.runBlocking { session.syncResultStore.latest() }
                currentRequestActivity = session.requestActivityTracker.latest()
                currentManifestPhotoCount = SuspendBridge.runBlocking {
                    session.manifestBuilder.buildM0Manifest().media.size
                }
                isServerStarting = false
                isServerRunning = true
                currentPairingPayloadJson = session.pairingPayloadJson
                AndroidM0ForegroundService.start(applicationContext)
                runOnUiThread { refreshUi() }
                pollSyncResultUpdates(session.syncResultStore)
            } catch (error: Throwable) {
                server = null
                AndroidM0ServerSessionRegistry.clear()
                AndroidM0ForegroundService.stop(applicationContext)
                restorePersistedSyncResult()
                manifestBuilder = null
                requestActivityTracker = null
                currentRequestActivity = null
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

    private fun stopServer() {
        val currentSession = AndroidM0ServerSessionRegistry.current
        val currentServer = server ?: currentSession?.server ?: return
        server = null
        AndroidM0ServerSessionRegistry.clear(currentSession)
        manifestBuilder = null
        requestActivityTracker = null
        currentManifestPhotoCount = null
        currentRequestActivity = null
        isServerStarting = false
        isServerRunning = false
        currentPairingPayloadJson = null
        restorePersistedSyncResult()
        syncResultPollThread?.interrupt()
        syncResultPollThread = null
        updateKeepScreenAwake()
        AndroidM0ForegroundService.stop(applicationContext)

        Thread {
            try {
                if (currentSession != null) {
                    AndroidM0ServerSessionController.stop(currentSession)
                } else {
                    SuspendBridge.runBlocking { currentServer.stop() }
                }
            } finally {
                runOnUiThread { refreshUi() }
            }
        }.start()
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

    private fun restoreRunningServerSession() {
        val session = AndroidM0ServerSessionRegistry.current ?: return
        server = session.server
        syncResultStore = session.syncResultStore
        manifestBuilder = session.manifestBuilder
        requestActivityTracker = session.requestActivityTracker
        currentPairingPayloadJson = session.pairingPayloadJson
        isServerStarting = false
        isServerRunning = true
        currentSyncResult = SuspendBridge.runBlocking { session.syncResultStore.latest() }
        currentRequestActivity = session.requestActivityTracker.latest()
        currentManifestPhotoCount = SuspendBridge.runBlocking {
            session.manifestBuilder.buildM0Manifest().media.size
        }
        pollSyncResultUpdates(session.syncResultStore)
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
                currentRequestActivity = requestActivityTracker?.latest()
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
        val failedCount = result.results.count { it.status.isRetryableFailure }
        val latestFailureCode = result.results
            .lastOrNull { it.status.isRetryableFailure }
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

    private fun formatRequestActivity(activity: LocalRequestActivity): String {
        return getString(
            R.string.m0_request_activity_summary,
            activity.endpoint,
            activity.endpointRequestCount,
            activity.statusCode,
            activity.requestCount,
            requestActivityAgeLabel(activity),
        )
    }

    private val SyncItemStatus.isRetryableFailure: Boolean
        get() = this == SyncItemStatus.failed || this == SyncItemStatus.conflicted

    private fun requestActivityAgeLabel(activity: LocalRequestActivity): String {
        val ageMillis = (System.currentTimeMillis() - activity.recordedAtEpochMillis).coerceAtLeast(0)
        val ageSeconds = ageMillis / 1_000
        return when {
            ageSeconds < 60 -> "${ageSeconds}s ago"
            ageSeconds < 3_600 -> "${ageSeconds / 60}m ago"
            else -> "${ageSeconds / 3_600}h ago"
        }
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
        const val SYNC_RESULT_POLL_INTERVAL_MS = 2_000L
    }
}
