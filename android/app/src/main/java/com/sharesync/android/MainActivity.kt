package com.sharesync.android

import android.Manifest
import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import com.sharesync.android.security.SharedPreferencesDeviceIdentityStore
import com.sharesync.android.runtime.PhotoSharingCoordinator
import com.sharesync.android.runtime.PhotoSharingCoordinatorEvent
import com.sharesync.android.runtime.PhotoSharingSnapshot
import com.sharesync.android.sync.SyncHistorySummary
import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncResult
import com.sharesync.android.sync.SyncResultJsonCodec
import com.sharesync.android.support.AndroidSupportSnapshotBuilder
import com.sharesync.android.support.AndroidSupportSnapshotInput
import com.sharesync.android.transfer.server.LocalRequestActivity
import com.sharesync.android.ui.MainDestination
import com.sharesync.android.ui.PhotoSharingScreenState
import com.sharesync.android.ui.PhotoSyncHomeUiState
import com.sharesync.android.ui.ActivityUiState
import com.sharesync.android.ui.HistoryUiItem
import com.sharesync.android.ui.SettingsUiState
import com.sharesync.android.ui.ShareSyncApp
import com.sharesync.android.ui.ShareSyncComposeTheme
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

class MainActivity : ComponentActivity() {
    private lateinit var sharingCoordinator: PhotoSharingCoordinator
    private var isServerRunning = false
    private var isServerStarting = false
    private var currentServerPort: Int? = null
    private var currentPairingPayloadJson: String? = null
    private var currentTransportSecurityMode: PhotoSharingTransportSecurityMode = PhotoSharingTransportSecurityMode.SIGNED_HTTP
    private var currentManifestPhotoCount: Int? = null
    private var currentSyncResult: SyncResult? = null
    private var currentSyncHistory: List<SyncHistorySummary> = emptyList()
    private var currentRequestActivity: LocalRequestActivity? = null
    private var hasConnectedPeer = false
    private var currentSection by mutableStateOf(MainDestination.SYNC)
    private var isAdvancedSupportExpanded by mutableStateOf(false)
    private var syncHomeState by mutableStateOf(PhotoSyncHomeUiState())
    private var activityUiState by mutableStateOf(ActivityUiState())
    private var settingsUiState by mutableStateOf(SettingsUiState())
    private var feedbackMessage by mutableStateOf<String?>(null)
    private var startSharingAfterPermission = false
    private val photoPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) {
        val shouldStart = startSharingAfterPermission
        startSharingAfterPermission = false
        if (shouldStart && hasMediaPermission()) enablePhotoSharing() else refreshUi()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentSection = savedInstanceState
            ?.getString(STATE_MAIN_SECTION)
            ?.let { stored -> MainDestination.entries.firstOrNull { it.name == stored } }
            ?: MainDestination.SYNC
        if (!hasCompletedOnboarding()) currentSection = MainDestination.SYNC
        isAdvancedSupportExpanded = savedInstanceState
            ?.getBoolean(STATE_ADVANCED_SUPPORT_EXPANDED)
            ?: false
        sharingCoordinator = PhotoSharingCoordinator(
            context = applicationContext,
            deviceIdentityStore = SharedPreferencesDeviceIdentityStore(this),
            appVersion = BuildConfig.VERSION_NAME,
            onUpdate = { snapshot, event ->
                window.decorView.post { handleCoordinatorUpdate(snapshot, event) }
            },
        )
        applySnapshot(sharingCoordinator.restore())
        renderProductContent()
        refreshUi()
        if (hasMediaPermission() && isPhotoSharingEnabled() && !isServerRunning) {
            startServer()
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString(STATE_MAIN_SECTION, currentSection.name)
        outState.putBoolean(STATE_ADVANCED_SUPPORT_EXPANDED, isAdvancedSupportExpanded)
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing) {
            stopServer()
        } else {
            sharingCoordinator.pauseMonitoring()
            updateKeepScreenAwake()
        }
    }

    private fun renderProductContent() {
        setContentView(ComposeView(this).apply {
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
            setContent {
                ShareSyncComposeTheme {
                    ShareSyncApp(
                        destination = currentSection,
                        home = syncHomeState,
                        activity = activityUiState,
                        settings = settingsUiState,
                        feedbackMessage = feedbackMessage,
                        onFeedbackShown = { feedbackMessage = null },
                        onDestinationChange = { currentSection = it },
                        onContinue = {
                            completeOnboarding()
                            requestPhotoPermissions()
                        },
                        onGrant = ::requestPhotoPermissions,
                        onGrantPhotos = ::requestMediaPermission,
                        onGrantNotifications = ::requestNotificationPermission,
                        onStart = ::enablePhotoSharing,
                        onStop = ::disablePhotoSharing,
                        onCopyPairing = ::copyPairingPayload,
                        onCopyEndpoint = ::copyEndpoint,
                        onCopyResult = ::copySyncResult,
                        onCopyDiagnostics = ::copyDiagnosticsSummary,
                        onClearHistory = ::showClearSyncStateConfirmation,
                        onToggleAdvanced = {
                            isAdvancedSupportExpanded = !isAdvancedSupportExpanded
                            refreshUi()
                        },
                    )
                }
            }
        })
    }

    private fun refreshUi(message: String? = null) {
        val endpointUrl = currentEndpointUrl()
        val screenState = PhotoSharingScreenState.from(
            runtime = runtimeState(),
            hasEndpoint = endpointUrl != null,
            hasPairingPayload = currentPairingPayloadJson != null,
            hasSyncResult = currentSyncResult != null,
        )
        val endpoint = endpointUrl?.let { getString(R.string.sync_endpoint, it) }
            ?: getString(R.string.sync_endpoint_unavailable)

        if (message != null) feedbackMessage = message
        val status = when {
            isServerRunning && currentManifestPhotoCount == 0 && currentSyncResult == null ->
                getString(R.string.home_sharing_empty)
            isServerRunning -> getString(R.string.sync_status_running)
            else -> getString(R.string.sync_status_ready)
        }

        syncHomeState = PhotoSyncHomeUiState(
            phase = if (screenState.phase == PhotoSharingPhase.TRANSFER_COMPLETE && currentSyncResult == null) {
                getString(R.string.sync_phase_ready_to_pair)
            } else {
                phaseStatus(screenState.phase)
            },
            status = status,
            photoCount = currentManifestPhotoCount,
            photoStatus = if (currentManifestPhotoCount == 0 && currentSyncResult == null) {
                getString(R.string.home_no_photos)
            } else {
                currentManifestPhotoCount?.let(::manifestTransferStatus).orEmpty()
            },
            guidance = nextStepInstruction(),
            pairingPayload = currentPairingPayloadJson,
            showPairing = screenState.showPairingPanel,
            showOnboarding = !hasCompletedOnboarding(),
            showGrant = screenState.showPhotoAccessAction,
            showStart = screenState.showStartAction,
            startEnabled = screenState.startActionEnabled,
            isRunning = isServerRunning,
            needsAttention = screenState.phase == PhotoSharingPhase.RETRY_REQUIRED,
        )
        activityUiState = ActivityUiState(
            latestResult = currentSyncResult?.let(::formatSyncResult)
                ?: getString(R.string.sync_result_unavailable),
            history = currentSyncHistory.map { summary ->
                HistoryUiItem(
                    date = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
                        .withLocale(resources.configuration.locales[0])
                        .format(Instant.ofEpochMilli(summary.recordedAtEpochMillis).atZone(ZoneId.systemDefault())),
                    completed = summary.successfulCount,
                    failed = summary.failedCount,
                )
            },
        )
        settingsUiState = SettingsUiState(
            networkReady = endpointUrl != null,
            photoAccess = hasMediaPermission(),
            notificationAccess = hasNotificationPermission(),
            sharing = isPhotoSharingEnabled(),
            endpoint = endpoint,
            requestActivity = currentRequestActivity?.let(::formatRequestActivity)
                ?: getString(R.string.sync_request_activity_unavailable),
            transportSecurity = transportSecurityStatusText(),
            pairingAvailable = screenState.copyPairingEnabled,
            endpointAvailable = screenState.copyEndpointEnabled,
            resultAvailable = screenState.copySyncResultEnabled,
            advancedExpanded = isAdvancedSupportExpanded,
        )

        updateKeepScreenAwake()
    }

    private fun requestPhotoPermissions() {
        requestMissingPermissions(requiredPhotoPermissions(), startSharing = true)
    }

    private fun requestMediaPermission() {
        requestMissingPermissions(requiredMediaPermissions())
    }

    private fun requestNotificationPermission() {
        requestMissingPermissions(requiredNotificationPermissions())
    }

    private fun requestMissingPermissions(permissions: List<String>, startSharing: Boolean = false) {
        val missing = permissions
            .filter { permission -> checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED }
            .toTypedArray()

        if (missing.isEmpty()) {
            if (startSharing && hasMediaPermission()) enablePhotoSharing()
            refreshUi()
            return
        }

        startSharingAfterPermission = startSharing
        photoPermissionLauncher.launch(missing)
    }

    private fun hasCompletedOnboarding(): Boolean {
        return getSharedPreferences(ONBOARDING_PREFERENCES, Context.MODE_PRIVATE)
            .getBoolean(ONBOARDING_COMPLETE_KEY, false)
    }

    private fun completeOnboarding() {
        getSharedPreferences(ONBOARDING_PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ONBOARDING_COMPLETE_KEY, true)
            .apply()
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

    private fun requiredPhotoPermissions(): List<String> {
        return requiredMediaPermissions() + requiredNotificationPermissions()
    }

    private fun startServer() {
        if (isServerRunning || isServerStarting) {
            return
        }

        if (!hasMediaPermission()) {
            requestPhotoPermissions()
            return
        }
        sharingCoordinator.start()
    }

    private fun stopServer() {
        sharingCoordinator.stop()
    }

    private fun enablePhotoSharing() {
        setPhotoSharingEnabled(true)
        startServer()
        refreshUi()
    }

    private fun disablePhotoSharing() {
        setPhotoSharingEnabled(false)
        stopServer()
        refreshUi()
    }

    private fun isPhotoSharingEnabled(): Boolean {
        return getSharedPreferences(SHARING_PREFERENCES, Context.MODE_PRIVATE)
            .getBoolean(SHARING_ENABLED_KEY, true)
    }

    private fun setPhotoSharingEnabled(enabled: Boolean) {
        getSharedPreferences(SHARING_PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(SHARING_ENABLED_KEY, enabled)
            .apply()
    }

    private fun copyPairingPayload() {
        val payload = currentPairingPayloadJson ?: return
        copyText(label = "ShareSync pairing payload", text = payload)
        refreshUi(getString(R.string.sync_pairing_payload_copied))
    }

    private fun copyEndpoint() {
        val endpointUrl = currentEndpointUrl() ?: return
        copyText(label = "ShareSync health endpoint", text = endpointUrl)
        refreshUi(getString(R.string.sync_endpoint_copied))
    }

    private fun copySyncResult() {
        val result = currentSyncResult ?: return
        val json = SyncResultJsonCodec().encode(result)
        copyText(label = "ShareSync sync result", text = json)
        refreshUi(getString(R.string.sync_result_copied))
    }

    private fun copyDiagnosticsSummary() {
        copyText(label = "ShareSync diagnostics", text = diagnosticsSummary())
        refreshUi(getString(R.string.diagnostics_copied))
    }

    private fun diagnosticsSummary(): String {
        return AndroidSupportSnapshotBuilder().build(
            AndroidSupportSnapshotInput(
                generatedAt = Instant.now().toString(),
                appVersion = BuildConfig.VERSION_NAME,
                buildNumber = BuildConfig.VERSION_CODE,
                phase = phaseStatus(runtimeState().phase()),
                nextStep = supportSnapshotNextStep(),
                transportSecurityMode = currentTransportSecurityMode,
                endpoint = currentEndpointUrl(),
                hasMediaPermission = hasMediaPermission(),
                hasNotificationPermission = hasNotificationPermission(),
                isServerRunning = isServerRunning,
                pendingPhotoCount = currentManifestPhotoCount,
                requestActivity = currentRequestActivity,
                syncResult = currentSyncResult,
            ),
        )
    }

    private fun copyText(label: String, text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText(label, text))
    }

    private fun clearSyncState() {
        sharingCoordinator.clearHistory()
    }

    private fun showClearSyncStateConfirmation() {
        AlertDialog.Builder(this)
            .setTitle(R.string.clear_history_title)
            .setMessage(R.string.clear_history_message)
            .setNegativeButton(R.string.clear_history_cancel, null)
            .setPositiveButton(R.string.clear_history_confirm) { _, _ ->
                clearSyncState()
            }
            .show()
    }

    private fun handleCoordinatorUpdate(
        snapshot: PhotoSharingSnapshot,
        event: PhotoSharingCoordinatorEvent?,
    ) {
        applySnapshot(snapshot)
        val message = when (event) {
            PhotoSharingCoordinatorEvent.Starting -> getString(R.string.sync_status_starting)
            PhotoSharingCoordinatorEvent.HistoryCleared -> getString(R.string.sync_state_cleared)
            is PhotoSharingCoordinatorEvent.Failed -> getString(
                R.string.sync_status_failed,
                event.error.message ?: "unknown error",
            )
            null -> null
        }
        refreshUi(message)
    }

    private fun applySnapshot(snapshot: PhotoSharingSnapshot) {
        isServerStarting = snapshot.isStarting
        isServerRunning = snapshot.isRunning
        currentServerPort = snapshot.serverPort
        currentPairingPayloadJson = snapshot.pairingPayloadJson
        currentTransportSecurityMode = snapshot.transportSecurityMode
        currentManifestPhotoCount = snapshot.pendingPhotoCount
        currentSyncResult = snapshot.syncResult
        currentSyncHistory = snapshot.syncHistory
        currentRequestActivity = snapshot.requestActivity
        hasConnectedPeer = snapshot.hasConnectedPeer
    }

    private fun currentEndpointUrl(): String? {
        val ip = LocalNetworkAddresses.firstIpv4Address() ?: return null
        val displayPort = currentServerPort ?: PhotoSyncComponents.defaultPort()
        val scheme = when (currentTransportSecurityMode) {
            PhotoSharingTransportSecurityMode.SIGNED_HTTP -> "http"
            PhotoSharingTransportSecurityMode.QR_PINNED_HTTPS -> "https"
        }
        return "$scheme://$ip:$displayPort/v1/health"
    }

    private fun updateKeepScreenAwake() {
        if (isServerRunning) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    private fun formatSyncResult(result: SyncResult): String {
        val syncedCount = result.results.count { it.status == SyncItemStatus.synced }
        val skippedCount = result.results.count { it.status == SyncItemStatus.skipped }
        val failedCount = result.results.count { it.status.isRetryableFailure }
        return getString(
            R.string.sync_result_summary,
            syncedCount,
            skippedCount,
            failedCount,
        )
    }

    private fun formatRequestActivity(activity: LocalRequestActivity): String {
        return getString(
            R.string.sync_request_activity_summary,
            activity.endpoint,
            activity.endpointRequestCount,
            activity.statusCode,
            activity.requestCount,
            requestActivityAgeLabel(activity),
        )
    }

    private fun transportSecurityStatusText(): String {
        return when (currentTransportSecurityMode) {
            PhotoSharingTransportSecurityMode.SIGNED_HTTP -> getString(R.string.transport_signed_http)
            PhotoSharingTransportSecurityMode.QR_PINNED_HTTPS -> getString(R.string.transport_qr_pinned_https)
        }
    }

    private val SyncItemStatus.isRetryableFailure: Boolean
        get() = this == SyncItemStatus.failed || this == SyncItemStatus.conflicted

    private fun requestActivityAgeLabel(activity: LocalRequestActivity): String {
        val ageMillis = (System.currentTimeMillis() - activity.recordedAtEpochMillis).coerceAtLeast(0)
        return ageLabel(ageMillis)
    }

    private fun ageLabel(ageMillis: Long): String {
        val ageSeconds = ageMillis / 1_000
        return when {
            ageSeconds < 60 -> getString(R.string.time_seconds_ago, ageSeconds)
            ageSeconds < 3_600 -> getString(R.string.time_minutes_ago, ageSeconds / 60)
            else -> getString(R.string.time_hours_ago, ageSeconds / 3_600)
        }
    }

    private fun runtimeState(): PhotoSharingRuntimeState {
        return PhotoSharingRuntimeState(
            hasMediaPermission = hasMediaPermission(),
            isServerStarting = isServerStarting,
            isServerRunning = isServerRunning,
            pendingPhotoCount = currentManifestPhotoCount,
            latestSyncResult = currentSyncResult,
            hasConnectedPeer = hasConnectedPeer,
        )
    }

    private fun phaseStatus(phase: PhotoSharingPhase): String {
        return when (phase) {
            PhotoSharingPhase.PERMISSION_REQUIRED -> getString(R.string.sync_phase_permission_required)
            PhotoSharingPhase.READY_TO_START -> getString(R.string.sync_phase_ready_to_start)
            PhotoSharingPhase.SERVER_STARTING -> getString(R.string.sync_phase_server_starting)
            PhotoSharingPhase.READY_TO_PAIR -> getString(R.string.sync_phase_ready_to_pair)
            PhotoSharingPhase.IPHONE_CONNECTED -> getString(R.string.sync_phase_iphone_connected)
            PhotoSharingPhase.RETRY_REQUIRED -> getString(R.string.sync_phase_retry_required)
            PhotoSharingPhase.TRANSFER_COMPLETE -> getString(R.string.sync_phase_transfer_complete)
        }
    }

    private fun nextStepInstruction(): String {
        return when (runtimeState().readiness().nextStep) {
            AndroidPhotoSyncNextStep.ALLOW_ANDROID_PHOTOS -> getString(R.string.next_step_allow_photos)
            AndroidPhotoSyncNextStep.START_ANDROID_SHARING -> getString(R.string.next_step_start_sharing)
            AndroidPhotoSyncNextStep.WAIT_FOR_ANDROID_SERVER -> getString(R.string.next_step_wait_for_server)
            AndroidPhotoSyncNextStep.SCAN_FROM_IPHONE -> getString(R.string.next_step_scan_from_iphone)
            AndroidPhotoSyncNextStep.KEEP_ANDROID_OPEN_FOR_TRANSFER -> getString(R.string.next_step_keep_open_for_transfer)
            AndroidPhotoSyncNextStep.KEEP_ANDROID_OPEN_FOR_RETRY -> getString(R.string.next_step_keep_open_for_retry)
            AndroidPhotoSyncNextStep.WAIT_FOR_NEW_ANDROID_PHOTOS -> getString(R.string.next_step_wait_for_new_photos)
        }
    }

    private fun supportSnapshotNextStep(): String {
        return when (runtimeState().readiness().nextStep) {
            AndroidPhotoSyncNextStep.ALLOW_ANDROID_PHOTOS -> "allow_android_photos"
            AndroidPhotoSyncNextStep.START_ANDROID_SHARING -> "start_android_sharing"
            AndroidPhotoSyncNextStep.WAIT_FOR_ANDROID_SERVER -> "wait_for_android_server"
            AndroidPhotoSyncNextStep.SCAN_FROM_IPHONE -> "scan_from_iphone"
            AndroidPhotoSyncNextStep.KEEP_ANDROID_OPEN_FOR_TRANSFER -> "wait_for_active_transfer"
            AndroidPhotoSyncNextStep.KEEP_ANDROID_OPEN_FOR_RETRY -> "wait_for_retry_resume"
            AndroidPhotoSyncNextStep.WAIT_FOR_NEW_ANDROID_PHOTOS -> "wait_for_new_android_photos"
        }
    }

    private fun manifestTransferStatus(pendingPhotoCount: Int): String {
        val state = runtimeState().copy(pendingPhotoCount = pendingPhotoCount)
        return when (state.manifestStatus()) {
            PhotoManifestStatus.COMPLETE -> getString(R.string.sync_manifest_status_complete)
            PhotoManifestStatus.NEEDS_RETRY -> getString(R.string.sync_manifest_status_needs_retry)
            PhotoManifestStatus.READY,
            null,
            -> getString(R.string.sync_manifest_status_ready)
        }
    }

    private companion object {
        const val STATE_MAIN_SECTION = "sharesync.mainSection"
        const val STATE_ADVANCED_SUPPORT_EXPANDED = "sharesync.advancedSupportExpanded"
        const val ONBOARDING_PREFERENCES = "sharesync_onboarding"
        const val ONBOARDING_COMPLETE_KEY = "completed"
        const val SHARING_PREFERENCES = "sharesync_sharing"
        const val SHARING_ENABLED_KEY = "enabled"
    }
}
