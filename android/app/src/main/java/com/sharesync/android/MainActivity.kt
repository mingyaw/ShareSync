package com.sharesync.android

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.res.ColorStateList
import android.content.pm.PackageManager
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.sharesync.android.pairing.QrCodeBitmapFactory
import com.sharesync.android.security.SharedPreferencesDeviceIdentityStore
import com.sharesync.android.runtime.PhotoSharingCoordinator
import com.sharesync.android.runtime.PhotoSharingCoordinatorEvent
import com.sharesync.android.runtime.PhotoSharingSnapshot
import com.sharesync.android.sync.SyncEvent
import com.sharesync.android.sync.SyncHistorySummary
import com.sharesync.android.sync.SyncItemStatus
import com.sharesync.android.sync.SyncResult
import com.sharesync.android.sync.SyncResultJsonCodec
import com.sharesync.android.support.AndroidSupportSnapshotBuilder
import com.sharesync.android.support.AndroidSupportSnapshotInput
import com.sharesync.android.transfer.server.LocalRequestActivity
import com.sharesync.android.ui.MainDestination
import com.sharesync.android.ui.PhotoSharingScreenState
import com.sharesync.android.ui.ShareSyncTheme
import java.time.Instant

class MainActivity : Activity() {
    private val shareSyncTheme: ShareSyncTheme by lazy { ShareSyncTheme.from(this) }

    private lateinit var statusText: TextView
    private lateinit var phaseText: TextView
    private lateinit var nextStepText: TextView
    private lateinit var endpointText: TextView
    private lateinit var permissionText: TextView
    private lateinit var notificationPermissionText: TextView
    private lateinit var screenLockText: TextView
    private lateinit var localNetworkText: TextView
    private lateinit var transportSecurityText: TextView
    private lateinit var manifestSummaryText: TextView
    private lateinit var syncEventText: TextView
    private lateinit var syncHistoryContainer: LinearLayout
    private lateinit var pairingInstructionText: TextView
    private lateinit var requestActivityText: TextView
    private lateinit var syncResultText: TextView
    private lateinit var pairingQrImage: ImageView
    private lateinit var pairingPanel: LinearLayout
    private lateinit var advancedSupportPanel: LinearLayout
    private lateinit var toggleAdvancedSupportButton: Button
    private lateinit var grantButton: Button
    private lateinit var startButton: Button
    private lateinit var stopButton: Button
    private lateinit var copyEndpointButton: Button
    private lateinit var copyPairingButton: Button
    private lateinit var copySyncResultButton: Button
    private lateinit var copyDiagnosticsButton: Button
    private lateinit var clearSyncStateButton: Button

    private lateinit var sharingCoordinator: PhotoSharingCoordinator
    private var isServerRunning = false
    private var isServerStarting = false
    private var currentServerPort: Int? = null
    private var currentPairingPayloadJson: String? = null
    private var currentTransportSecurityMode: PhotoSharingTransportSecurityMode = PhotoSharingTransportSecurityMode.SIGNED_HTTP
    private var currentManifestPhotoCount: Int? = null
    private var currentSyncResult: SyncResult? = null
    private var currentSyncEvent: SyncEvent? = null
    private var currentSyncHistory: List<SyncHistorySummary> = emptyList()
    private var currentRequestActivity: LocalRequestActivity? = null
    private var currentSection = MainDestination.SYNC
    private var isAdvancedSupportExpanded = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentSection = savedInstanceState
            ?.getString(STATE_MAIN_SECTION)
            ?.let { stored -> MainDestination.entries.firstOrNull { it.name == stored } }
            ?: MainDestination.SYNC
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
        renderContent()
        refreshUi()
        if (hasMediaPermission() && !isServerRunning) {
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_MEDIA_PERMISSION) {
            if (hasMediaPermission()) {
                startServer()
            } else {
                refreshUi()
            }
        }
    }

    private fun renderContent() {
        val density = resources.displayMetrics.density
        val padding = (20 * density).toInt()

        val screen = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(shareSyncTheme.background)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        val scrollView = ScrollView(this).apply {
            isFillViewport = true
            setBackgroundColor(shareSyncTheme.background)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f,
            ).apply { height = 0 }
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

        val brand = TextView(this).apply {
            text = getString(R.string.app_name)
            textSize = 15f
            setTextColor(shareSyncTheme.primary)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, (8 * density).toInt())
        }
        val title = TextView(this).apply {
            text = getString(currentSection.titleRes)
            textSize = 26f
            setTextColor(shareSyncTheme.textPrimary)
            typeface = Typeface.DEFAULT_BOLD
            isAccessibilityHeading = true
        }
        val subtitle = TextView(this).apply {
            text = getString(currentSection.subtitleRes)
            textSize = 15f
            setTextColor(shareSyncTheme.textSecondary)
            setPadding(0, (4 * density).toInt(), 0, (18 * density).toInt())
        }

        statusText = bodyText()
        statusText.accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        phaseText = bodyText()
        phaseText.apply {
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(shareSyncTheme.textPrimary)
            isAccessibilityHeading = true
        }
        nextStepText = bodyText().apply {
            textSize = 17f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(shareSyncTheme.textPrimary)
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        endpointText = bodyText()
        permissionText = bodyText()
        notificationPermissionText = bodyText()
        screenLockText = bodyText()
        localNetworkText = bodyText()
        transportSecurityText = bodyText()
        manifestSummaryText = bodyText()
        syncEventText = bodyText()
        syncHistoryContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        pairingInstructionText = bodyText()
        requestActivityText = bodyText()
        syncResultText = bodyText()
        pairingQrImage = ImageView(this).apply {
            adjustViewBounds = true
            contentDescription = getString(R.string.pairing_qr_accessibility)
            background = panelBackground(accentColor = shareSyncTheme.primary, filled = false)
            setPadding(8, 8, 8, 8)
            visibility = ImageView.GONE
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = (16 * density).toInt()
            }
        }

        grantButton = Button(this).apply {
            text = getString(R.string.sync_grant_permissions)
            setOnClickListener { requestPhotoPermissions() }
            fullWidthButtonLayout()
        }

        startButton = Button(this).apply {
            text = getString(R.string.sync_start_server)
            setOnClickListener { startServer() }
            fullWidthButtonLayout()
        }

        stopButton = Button(this).apply {
            text = getString(R.string.sync_stop_server)
            setOnClickListener { stopServer() }
            fullWidthButtonLayout(emphasized = false)
        }

        copyEndpointButton = Button(this).apply {
            text = getString(R.string.sync_copy_endpoint)
            setOnClickListener { copyEndpoint() }
            fullWidthButtonLayout(emphasized = false)
        }

        copyPairingButton = Button(this).apply {
            text = getString(R.string.sync_copy_pairing_payload)
            setOnClickListener { copyPairingPayload() }
            fullWidthButtonLayout(emphasized = false)
        }

        copySyncResultButton = Button(this).apply {
            text = getString(R.string.sync_copy_sync_result)
            setOnClickListener { copySyncResult() }
            fullWidthButtonLayout(emphasized = false)
        }

        copyDiagnosticsButton = Button(this).apply {
            text = getString(R.string.diagnostics_copy_diagnostics)
            setOnClickListener { copyDiagnosticsSummary() }
            fullWidthButtonLayout(emphasized = false)
        }

        clearSyncStateButton = Button(this).apply {
            text = getString(R.string.sync_clear_sync_state)
            setOnClickListener { showClearSyncStateConfirmation() }
            fullWidthButtonLayout(emphasized = false)
        }
        toggleAdvancedSupportButton = Button(this).apply {
            setOnClickListener {
                isAdvancedSupportExpanded = !isAdvancedSupportExpanded
                updateAdvancedSupportVisibility()
            }
            fullWidthButtonLayout(emphasized = false)
        }

        root.addView(brand)
        root.addView(title)
        root.addView(subtitle)
        if (currentSection == MainDestination.SYNC && !hasCompletedOnboarding()) {
            val onboardingText = bodyText().apply {
                text = getString(R.string.onboarding_body)
            }
            val onboardingPrivacyText = bodyText().apply {
                text = getString(R.string.onboarding_privacy)
            }
            val onboardingButton = Button(this).apply {
                text = getString(R.string.onboarding_continue)
                setOnClickListener {
                    completeOnboarding()
                    renderContent()
                    refreshUi()
                }
                fullWidthButtonLayout()
            }
            root.addView(
                productPanel(
                    title = getString(R.string.onboarding_title),
                    accentColor = shareSyncTheme.info,
                    children = listOf(onboardingText, onboardingPrivacyText, onboardingButton),
                ),
            )
        }
        when (currentSection) {
            MainDestination.SYNC -> {
                root.addView(
                    productPanel(
                        title = getString(R.string.sync_panel_summary),
                        accentColor = shareSyncTheme.primary,
                        children = listOf(
                            phaseText,
                            statusText,
                            manifestSummaryText,
                            grantButton,
                            startButton,
                            stopButton,
                            nextStepText,
                        ),
                    ),
                )
                pairingPanel = productPanel(
                    title = getString(R.string.sync_panel_pairing),
                    accentColor = shareSyncTheme.info,
                    children = listOf(pairingInstructionText, pairingQrImage),
                )
                root.addView(pairingPanel)
            }

            MainDestination.ACTIVITY -> {
                root.addView(
                    productPanel(
                        title = getString(R.string.ui_recent_activity),
                        accentColor = shareSyncTheme.primary,
                        children = listOf(syncEventText, syncHistoryContainer, syncResultText),
                    ),
                )
            }

            MainDestination.SETTINGS -> {
                root.addView(
                    productPanel(
                        title = getString(R.string.ui_privacy_connection),
                        accentColor = shareSyncTheme.info,
                        children = listOf(
                            bodyText().apply { text = getString(R.string.privacy_summary) },
                            bodyText().apply { text = getString(R.string.privacy_storage) },
                            localNetworkText,
                            permissionText,
                            notificationPermissionText,
                            screenLockText,
                            transportSecurityText,
                        ),
                    ),
                )
                root.addView(
                    productPanel(
                        title = getString(R.string.ui_connection_tools),
                        accentColor = shareSyncTheme.warning,
                        children = listOf(copyPairingButton),
                    ),
                )
                root.addView(toggleAdvancedSupportButton)
                advancedSupportPanel = productPanel(
                    title = getString(R.string.sync_panel_diagnostics),
                    accentColor = shareSyncTheme.textSecondary,
                    children = listOf(
                        endpointText,
                        requestActivityText,
                        copyEndpointButton,
                        copySyncResultButton,
                        copyDiagnosticsButton,
                        clearSyncStateButton,
                    ),
                )
                root.addView(advancedSupportPanel)
            }
        }
        scrollView.addView(root)
        screen.addView(scrollView)
        screen.addView(bottomNavigation())
        setContentView(screen)
    }

    private fun bottomNavigation(): LinearLayout {
        val density = resources.displayMetrics.density
        return LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(
                (8 * density).toInt(),
                (6 * density).toInt(),
                (8 * density).toInt(),
                (8 * density).toInt(),
            )
            setBackgroundColor(shareSyncTheme.surface)
            elevation = 8 * density
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            MainDestination.entries.forEach { section ->
                addView(Button(context).apply {
                    text = getString(section.navigationRes)
                    setCompoundDrawablesRelativeWithIntrinsicBounds(0, section.iconRes, 0, 0)
                    compoundDrawableTintList = ColorStateList.valueOf(
                        if (section == currentSection) shareSyncTheme.primary else shareSyncTheme.textSecondary,
                    )
                    compoundDrawablePadding = (3 * density).toInt()
                    isAllCaps = false
                    textSize = 13f
                    setTextColor(if (section == currentSection) shareSyncTheme.primary else shareSyncTheme.textSecondary)
                    typeface = if (section == currentSection) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
                    minHeight = (56 * density).toInt()
                    background = if (section == currentSection) {
                        panelBackground(accentColor = shareSyncTheme.primary)
                    } else {
                        GradientDrawable().apply { setColor(shareSyncTheme.surface) }
                    }
                    layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply {
                        marginStart = (3 * density).toInt()
                        marginEnd = (3 * density).toInt()
                    }
                    setOnClickListener {
                        if (currentSection != section) {
                            currentSection = section
                            renderContent()
                            refreshUi()
                        }
                    }
                })
            }
        }
    }

    private fun bodyText(): TextView {
        return TextView(this).apply {
            textSize = 16f
            setTextColor(shareSyncTheme.textSecondary)
            setLineSpacing(0f, 1.12f)
            setPadding(0, (8 * resources.displayMetrics.density).toInt(), 0, 0)
        }
    }

    private fun productPanel(
        title: String,
        accentColor: Int = shareSyncTheme.primary,
        children: List<android.view.View>,
    ): LinearLayout {
        val density = resources.displayMetrics.density
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(
                (16 * density).toInt(),
                (14 * density).toInt(),
                (16 * density).toInt(),
                (16 * density).toInt(),
            )
            background = panelBackground(accentColor = accentColor)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                bottomMargin = (14 * density).toInt()
            }

            addView(TextView(context).apply {
                text = title
                textSize = 16f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(accentColor)
                isAccessibilityHeading = true
                setPadding(0, 0, 0, (8 * density).toInt())
            })
            children.forEach(::addView)
        }
    }

    private fun panelBackground(accentColor: Int, filled: Boolean = true): GradientDrawable {
        val density = resources.displayMetrics.density
        return GradientDrawable().apply {
            setColor(if (filled) shareSyncTheme.surface else shareSyncTheme.qrSurface)
            cornerRadius = 8 * density
            setStroke(1, if (filled) shareSyncTheme.divider else accentColor)
        }
    }

    private fun Button.fullWidthButtonLayout(emphasized: Boolean = true) {
        val density = resources.displayMetrics.density
        isAllCaps = false
        minHeight = (48 * density).toInt()
        val enabledBackground = if (emphasized) shareSyncTheme.primary else shareSyncTheme.surfaceAlt
        val enabledText = if (emphasized) shareSyncTheme.onPrimary else shareSyncTheme.primary
        val states = arrayOf(
            intArrayOf(-android.R.attr.state_enabled),
            intArrayOf(),
        )
        backgroundTintList = ColorStateList(
            states,
            intArrayOf(shareSyncTheme.divider, enabledBackground),
        )
        setTextColor(
            ColorStateList(
                states,
                intArrayOf(shareSyncTheme.textSecondary, enabledText),
            ),
        )
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply {
            topMargin = (10 * density).toInt()
        }
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

        val status = when {
            message != null -> message
            isServerRunning -> getString(R.string.sync_status_running)
            else -> getString(R.string.sync_status_ready)
        }

        statusText.text = status
        statusText.setTextColor(
            when {
                isServerRunning -> shareSyncTheme.success
                message != null -> shareSyncTheme.info
                else -> shareSyncTheme.textSecondary
            },
        )
        phaseText.text = phaseStatus(screenState.phase)
        phaseText.setTextColor(if (isServerRunning) shareSyncTheme.primary else shareSyncTheme.textSecondary)
        nextStepText.text = getString(R.string.next_step, nextStepInstruction())
        endpointText.text = endpoint
        permissionText.text = if (hasMediaPermission()) {
            getString(R.string.sync_permission_granted)
        } else {
            getString(R.string.sync_permission_missing)
        }
        notificationPermissionText.text = if (hasNotificationPermission()) {
            getString(R.string.sync_notification_permission_granted)
        } else {
            getString(R.string.sync_notification_permission_missing)
        }
        screenLockText.text = if (isServerRunning) {
            getString(R.string.sync_screen_lock_paused)
        } else {
            getString(R.string.sync_screen_lock_normal)
        }
        localNetworkText.text = if (endpointUrl == null) {
            getString(R.string.readiness_local_network_unavailable)
        } else {
            getString(R.string.readiness_local_network_ready)
        }
        transportSecurityText.text = transportSecurityStatusText()
        pairingInstructionText.text = readinessInstruction()
        manifestSummaryText.text = currentManifestPhotoCount?.let { count ->
            getString(R.string.sync_manifest_summary, count, manifestTransferStatus(count))
        } ?: getString(R.string.sync_manifest_unavailable)
        requestActivityText.text = currentRequestActivity?.let(::formatRequestActivity)
            ?: getString(R.string.sync_request_activity_unavailable)
        syncResultText.text = currentSyncResult?.let(::formatSyncResult)
            ?: getString(R.string.sync_result_unavailable)
        syncEventText.text = currentSyncEvent?.let(::formatSyncEvent)
            ?: getString(R.string.activity_event_unavailable)
        renderSyncHistory()
        refreshPairingQr()
        if (currentSection == MainDestination.SYNC && ::pairingPanel.isInitialized) {
            pairingPanel.visibility = if (screenState.showPairingPanel) View.VISIBLE else View.GONE
        }

        startButton.isEnabled = screenState.startActionEnabled
        stopButton.isEnabled = screenState.stopActionEnabled
        grantButton.visibility = if (screenState.showPhotoAccessAction) View.VISIBLE else View.GONE
        startButton.visibility = if (screenState.showStartAction) View.VISIBLE else View.GONE
        stopButton.visibility = if (screenState.showStopAction) View.VISIBLE else View.GONE
        copyEndpointButton.isEnabled = screenState.copyEndpointEnabled
        copyPairingButton.isEnabled = screenState.copyPairingEnabled
        copySyncResultButton.isEnabled = screenState.copySyncResultEnabled
        copyDiagnosticsButton.isEnabled = true
        clearSyncStateButton.isEnabled = currentSyncResult != null
        updateAdvancedSupportVisibility()
        updateKeepScreenAwake()
    }

    private fun updateAdvancedSupportVisibility() {
        if (currentSection != MainDestination.SETTINGS || !::advancedSupportPanel.isInitialized) {
            return
        }
        advancedSupportPanel.visibility = if (isAdvancedSupportExpanded) View.VISIBLE else View.GONE
        toggleAdvancedSupportButton.text = getString(
            if (isAdvancedSupportExpanded) {
                R.string.settings_hide_advanced_support
            } else {
                R.string.settings_show_advanced_support
            },
        )
    }

    private fun requestPhotoPermissions() {
        val missing = requiredPhotoPermissions()
            .filter { permission -> checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED }
            .toTypedArray()

        if (missing.isEmpty()) {
            refreshUi()
            return
        }

        requestPermissions(missing, REQUEST_MEDIA_PERMISSION)
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
        currentSyncEvent = snapshot.syncEvent
        currentSyncHistory = snapshot.syncHistory
        currentRequestActivity = snapshot.requestActivity
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

    private fun formatSyncEvent(event: SyncEvent): String {
        return getString(
            R.string.activity_event_summary,
            syncEventAgeLabel(event),
            event.syncedCount,
            event.skippedCount,
            event.failedCount + event.conflictedCount,
        )
    }

    private fun renderSyncHistory() {
        syncHistoryContainer.removeAllViews()
        if (currentSyncHistory.isEmpty()) {
            syncHistoryContainer.addView(bodyText().apply { text = getString(R.string.history_unavailable) })
            return
        }

        currentSyncHistory.forEachIndexed { index, summary ->
            if (index > 0) {
                syncHistoryContainer.addView(android.view.View(this).apply {
                    setBackgroundColor(shareSyncTheme.divider)
                    layoutParams = LinearLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        resources.displayMetrics.density.toInt().coerceAtLeast(1),
                    ).apply {
                        topMargin = (10 * resources.displayMetrics.density).toInt()
                    }
                })
            }
            syncHistoryContainer.addView(bodyText().apply {
                text = ageLabel((System.currentTimeMillis() - summary.recordedAtEpochMillis).coerceAtLeast(0))
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(shareSyncTheme.textPrimary)
            })
            syncHistoryContainer.addView(bodyText().apply {
                text = getString(
                    R.string.history_item_summary,
                    summary.successfulCount,
                    summary.failedCount,
                )
                if (summary.failedCount > 0) {
                    setTextColor(shareSyncTheme.warning)
                }
            })
        }
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

    private fun syncEventAgeLabel(event: SyncEvent): String {
        val ageMillis = (System.currentTimeMillis() - event.recordedAtEpochMillis).coerceAtLeast(0)
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
            hasConnectedPeer = hasConnectedIphone(),
        )
    }

    private fun hasConnectedIphone(): Boolean {
        val activity = currentRequestActivity ?: return false
        return activity.statusCode in 200..299 && activity.endpoint in AUTHENTICATED_PHOTO_ENDPOINTS
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

    private fun readinessInstruction(): String {
        return when (runtimeState().readiness().primaryAction) {
            AndroidPhotoSyncPrimaryAction.ALLOW_PHOTOS -> getString(R.string.readiness_allow_photos)
            AndroidPhotoSyncPrimaryAction.START_SHARING -> getString(R.string.readiness_start_sharing)
            AndroidPhotoSyncPrimaryAction.WAIT_FOR_SERVER -> getString(R.string.readiness_wait_for_server)
            AndroidPhotoSyncPrimaryAction.SHOW_PAIRING_CODE -> getString(R.string.readiness_show_pairing_code)
            AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_TRANSFER -> getString(R.string.readiness_keep_available_for_transfer)
            AndroidPhotoSyncPrimaryAction.KEEP_AVAILABLE_FOR_RETRY -> getString(R.string.readiness_keep_available_for_retry)
            AndroidPhotoSyncPrimaryAction.WAIT_FOR_NEW_PHOTOS -> getString(R.string.readiness_wait_for_new_photos)
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
        const val REQUEST_MEDIA_PERMISSION = 1001
        val AUTHENTICATED_PHOTO_ENDPOINTS = setOf("manifest", "media", "sync-result")
    }
}
