import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("autoSyncAllPhotos") private var autoSyncAllPhotos = true
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @StateObject private var viewModel = ManifestFetchViewModel()
    @State private var isShowingPairingScanner = false
    @State private var syncResultCopyMessage: String?
    @State private var isSettingsExpanded = false
    @State private var pendingDestructiveAction: DestructiveAction?
    @State private var selectedTab: AppTab = .receive

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                receiveScreen
                    .navigationTitle("ShareSync")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("ios.tab.receive", systemImage: "arrow.down.circle")
            }
            .tag(AppTab.receive)

            NavigationStack {
                activityScreen
                    .navigationTitle("ios.tab.activity")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("ios.tab.activity", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppTab.activity)

            NavigationStack {
                settingsScreen
                    .navigationTitle("ios.tab.settings")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("ios.tab.settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .tint(ShareSyncTheme.primary)
        .fullScreenCover(isPresented: $isShowingPairingScanner) {
            QRCodeScannerView { payload in
                viewModel.pairingPayloadText = payload
                viewModel.applyPairingPayload()
                if autoSyncAllPhotos {
                    viewModel.syncAllPhotos()
                }
            }
        }
        .confirmationDialog(
            destructiveDialogTitle,
            isPresented: isShowingDestructiveConfirmation,
            titleVisibility: .visible
        ) {
            Button(destructiveConfirmLabel, role: .destructive) {
                performPendingDestructiveAction()
            }
            Button("ios.confirm.cancel", role: .cancel) {}
        } message: {
            Text(destructiveDialogMessage)
        }
        .onChange(of: viewModel.downloadState) { _, newState in
            updateIdleTimer(for: newState)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                viewModel.cancelDownloadForBackground()
            }
        }
        .onChange(of: isPaired) { _, paired in
            if paired {
                hasCompletedWelcome = true
                selectedTab = .receive
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var receiveScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                if !hasCompletedWelcome && !isPaired {
                    welcomePanel
                } else {
                    transferSummaryPanel
                    if isPaired {
                        primaryActions
                    } else {
                        pairingPanel
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 680, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
        .background(ShareSyncTheme.background)
    }

    private var activityScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProductPanel(title: "ios.activity.summary") {
                    statusSectionContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 680, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
        .background(ShareSyncTheme.background)
    }

    private var settingsScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProductPanel(title: "ios.settings.sync") {
                    Toggle("ios.action.auto_sync_all", isOn: $autoSyncAllPhotos)
                        .disabled(viewModel.isTransferActive)
                    Text("ios.settings.auto_sync_note")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ProductPanel(title: "ios.privacy.title") {
                    privacyPanelContent
                }

                settingsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 680, alignment: .topLeading)
            .frame(maxWidth: .infinity)
        }
        .background(ShareSyncTheme.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(isPaired ? "ios.home.connected" : "ios.home.not_connected", systemImage: isPaired ? "checkmark.circle.fill" : "iphone.and.arrow.forward")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isPaired ? ShareSyncTheme.success : ShareSyncTheme.info)
                .accessibilityAddTraits(.isHeader)

            Text("ios.header.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transferSummaryPanel: some View {
        ProductPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phaseStatus)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(summarySubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let readinessReasonText {
                            Text(readinessReasonText)
                                .font(.footnote)
                                .foregroundStyle(summaryTone.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 12)
                    Image(systemName: summaryIconName)
                        .font(.title2)
                        .foregroundStyle(summaryTone.color)
                }

                if let summary = viewModel.summary {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            summaryMetrics(summary)
                        }
                        VStack(spacing: 10) {
                            summaryMetrics(summary)
                        }
                    }
                }

                Divider()

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: nextStepIconName)
                        .font(.headline)
                        .foregroundStyle(summaryTone.color)
                        .frame(width: 22, alignment: .center)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("ios.next_step.title")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(nextStepText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var welcomePanel: some View {
        ProductPanel(title: "ios.welcome.title") {
            VStack(alignment: .leading, spacing: 12) {
                Label("ios.welcome.local", systemImage: "wifi")
                Label("ios.welcome.private", systemImage: "lock.shield")
                Label("ios.welcome.foreground", systemImage: "iphone")

                Button {
                    hasCompletedWelcome = true
                    isShowingPairingScanner = true
                } label: {
                    Label("ios.welcome.start", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var primaryActions: some View {
        ProductPanel {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    performPrimaryReadinessAction()
                } label: {
                    Label(primaryReadinessButtonTitle, systemImage: primaryReadinessButtonIcon)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!primaryReadinessActionEnabled)

                if viewModel.canCancelDownload {
                    Button(role: .cancel) {
                        viewModel.cancelDownload()
                    } label: {
                        Label("ios.action.stop_transfer", systemImage: "stop.circle")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                }

                if viewModel.isTransferActive {
                    VStack(alignment: .leading, spacing: 8) {
                        if let progress = viewModel.downloadProgressSummary, progress.totalCount > 0 {
                            ProgressView(
                                value: Double(progress.processedCount),
                                total: Double(progress.totalCount)
                            )
                            .tint(ShareSyncTheme.primary)
                            Text(
                                String(
                                    format: localized("ios.progress.photos_format"),
                                    String(progress.processedCount),
                                    String(progress.totalCount)
                                )
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            if let currentFileName = progress.currentFileName {
                                Text(currentFileName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        } else {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(ShareSyncTheme.primary)
                                Text("ios.feedback.transfer_active")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                Text("ios.footer.foreground")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var pairingPanel: some View {
        ProductPanel(title: "ios.pairing.title") {
            VStack(alignment: .leading, spacing: 12) {
                Text("ios.pairing.prompt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    isShowingPairingScanner = true
                } label: {
                    Label("ios.action.scan_pairing_qr", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Label("ios.pairing.same_network", systemImage: "wifi")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settingsSection: some View {
        ProductPanel(title: "ios.settings.support") {
            DisclosureGroup(isExpanded: $isSettingsExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    connectionPanelContent
                    Divider()
                    diagnosticsPanelContent
                }
                .padding(.top, 10)
            } label: {
                Label("ios.settings.advanced", systemImage: "wrench.and.screwdriver")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }

    private var privacyPanelContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("ios.privacy.local_transfer", systemImage: "network")
            Label("ios.privacy.no_relay", systemImage: "icloud.slash")
            Label("ios.privacy.local_history", systemImage: "internaldrive")
            Text("ios.privacy.icloud_note")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var connectionPanel: some View {
        ProductPanel(title: "ios.panel.connection") {
            connectionPanelContent
        }
    }

    private var connectionPanelContent: some View {
            VStack(alignment: .leading, spacing: 14) {
                Button {
                    isShowingPairingScanner = true
                } label: {
                    Label("ios.action.scan_pairing_qr", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                TextField("ios.connection.android_ip", text: $viewModel.host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity, minHeight: 48)

                TextField("ios.connection.port", text: $viewModel.port)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity, minHeight: 48)

                TextEditor(text: $viewModel.pairingPayloadText)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    }

                Button {
                    viewModel.applyPairingPayload()
                } label: {
                    Label("ios.action.use_pairing_payload", systemImage: "link")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
    }

    private var diagnosticsPanel: some View {
        ProductPanel(title: "ios.panel.diagnostics") {
            diagnosticsPanelContent
        }
    }

    private var diagnosticsPanelContent: some View {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    viewModel.fetchManifest()
                } label: {
                    Label(buttonTitle, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canFetch)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        downloadNextButton
                        downloadFiveButton
                    }
                    VStack(spacing: 12) {
                        downloadNextButton
                        downloadFiveButton
                    }
                }

                Button {
                    copySyncResult()
                } label: {
                    Label("ios.action.copy_sync_result", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.latestSyncResultJSON == nil)

                Button {
                    copyDiagnosticsSummary()
                } label: {
                    Label("ios.action.copy_diagnostics", systemImage: "stethoscope")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    pendingDestructiveAction = .resetHistory
                } label: {
                    Label("ios.action.reset_local_sync_state", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isTransferActive)

                Button(role: .destructive) {
                    pendingDestructiveAction = .forgetPhone
                } label: {
                    Label("ios.action.clear_pairing", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isTransferActive || !viewModel.canClearPairing)
            }
    }

    private var downloadNextButton: some View {
        Button {
            viewModel.downloadFirstMedia()
        } label: {
            Label("ios.action.next", systemImage: "arrow.down.to.line")
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!viewModel.canDownload)
    }

    private var downloadFiveButton: some View {
        Button {
            viewModel.downloadSmallMediaBatch()
        } label: {
            Label("ios.action.five_photos", systemImage: "square.stack.3d.down.right")
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!viewModel.canDownload)
    }

    @ViewBuilder
    private func summaryMetrics(_ summary: ManifestFetchViewModel.ManifestSummary) -> some View {
        MetricView(title: "ios.metric.photos", value: "\(summary.photoCount)", tone: .info)
        MetricView(title: "ios.metric.done", value: "\(summary.importedCount + summary.downloadedCount)", tone: .success)
        MetricView(title: "ios.metric.left", value: "\(summary.remainingCount)", tone: .primary)
    }

    private var statusSection: some View {
        ProductPanel(title: "ios.panel.status") {
            statusSectionContent
        }
    }

    private var statusSectionContent: some View {
            VStack(alignment: .leading, spacing: 12) {
                StatusRow(title: "ios.status.pairing", value: pairedStatus)
                StatusRow(title: "ios.status.binding", value: bindingStatusText)
                StatusRow(title: "ios.status.photos_access", value: photosAccessStatus)
                StatusRow(title: "ios.status.screen_lock", value: screenLockStatus)
                StatusRow(title: "ios.status.last_sync", value: latestSyncText)
                if !viewModel.recentSyncHistory.isEmpty {
                    StatusRow(title: "ios.status.recent_syncs", value: recentSyncHistoryText)
                }
                if let pairedDevice = viewModel.pairedDevice {
                    StatusRow(title: "ios.status.device", value: pairedDevice.deviceName)
                }
                if let health = viewModel.localPeerHealth {
                    StatusRow(title: "ios.status.android_peer", value: androidPeerText(health))
                }
                StatusRow(title: "ios.status.manifest", value: manifestStatus)

                if let summary = viewModel.summary {
                    StatusRow(title: "ios.status.photos", value: "\(summary.photoCount)")
                    StatusRow(title: "ios.status.transfer", value: localizedTransferStatus(summary.transferStatus))
                    StatusRow(title: "ios.status.transfer_size", value: ByteCountFormatter.string(fromByteCount: summary.totalBytes, countStyle: .file))
                    StatusRow(title: "ios.status.test_item", value: summary.validationAssetName ?? localized("ios.value.none"))
                    StatusRow(title: "ios.status.downloaded", value: "\(summary.downloadedCount)")
                    StatusRow(title: "ios.status.imported", value: "\(summary.importedCount)")
                    StatusRow(title: "ios.status.missing", value: "\(summary.missingCount)")
                    StatusRow(title: "ios.status.failed", value: "\(summary.failedCount)")
                    StatusRow(title: "ios.status.partial", value: "\(summary.partialCount)")
                    if let lastFailureCode = summary.lastFailureCode {
                        StatusRow(title: "ios.status.last_failure", value: lastFailureText(code: lastFailureCode, fileName: summary.lastFailureFileName))
                    }
                    StatusRow(title: "ios.status.remaining", value: "\(summary.remainingCount)")
                    StatusRow(title: "ios.status.cursor", value: summary.cursor)
                } else {
                    StatusRow(title: "ios.status.photos", value: localized("ios.status.waiting"))
                }

                if let progress = viewModel.downloadProgressSummary {
                    StatusRow(title: "ios.status.batch_progress", value: progress.progressText)
                    StatusRow(title: "ios.status.batch_downloaded", value: "\(progress.downloadedCount)")
                    StatusRow(title: "ios.status.batch_failed", value: "\(progress.failedCount)")
                    if let currentFileName = progress.currentFileName {
                        StatusRow(title: "ios.status.current_file", value: currentFileName)
                    }
                }

                if let syncResultSummary = viewModel.syncResultSummary {
                    StatusRow(title: "ios.status.sync_batch", value: syncResultSummary.syncBatchId)
                    StatusRow(title: "ios.status.synced", value: "\(syncResultSummary.syncedCount)")
                    StatusRow(title: "ios.status.skipped", value: "\(syncResultSummary.skippedCount)")
                    StatusRow(title: "ios.status.result_failed", value: "\(syncResultSummary.failedCount)")
                }
                if let returnSummary = viewModel.syncResultReturnSummary {
                    StatusRow(title: "ios.status.result_return", value: syncResultReturnText(returnSummary))
                }

                if viewModel.latestSyncResultJSON != nil, let syncResultCopyMessage {
                    FeedbackMessage(message: syncResultCopyMessage, tone: .success)
                }

                if case .cancelled = viewModel.downloadState {
                    FeedbackMessage(
                        message: viewModel.cancellationMessage ?? localized("ios.transfer.cancelled_default"),
                        tone: .warning
                    )
                }

                if case .failed(let message) = viewModel.state {
                    FeedbackMessage(message: message, tone: .error)
                }

                if case .failed(let message) = viewModel.downloadState {
                    FeedbackMessage(message: message, tone: .error)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isPaired: Bool {
        !viewModel.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isShowingDestructiveConfirmation: Binding<Bool> {
        Binding(
            get: { pendingDestructiveAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDestructiveAction = nil
                }
            }
        )
    }

    private var destructiveDialogTitle: LocalizedStringKey {
        switch pendingDestructiveAction {
        case .resetHistory:
            return "ios.confirm.reset_history.title"
        case .forgetPhone:
            return "ios.confirm.forget_phone.title"
        case nil:
            return ""
        }
    }

    private var destructiveDialogMessage: LocalizedStringKey {
        switch pendingDestructiveAction {
        case .resetHistory:
            return "ios.confirm.reset_history.message"
        case .forgetPhone:
            return "ios.confirm.forget_phone.message"
        case nil:
            return ""
        }
    }

    private var destructiveConfirmLabel: LocalizedStringKey {
        switch pendingDestructiveAction {
        case .resetHistory:
            return "ios.confirm.reset_history.confirm"
        case .forgetPhone:
            return "ios.confirm.forget_phone.confirm"
        case nil:
            return ""
        }
    }

    private func performPendingDestructiveAction() {
        defer { pendingDestructiveAction = nil }
        switch pendingDestructiveAction {
        case .resetHistory:
            viewModel.resetLocalSyncState()
        case .forgetPhone:
            viewModel.clearPairing()
        case nil:
            break
        }
    }

    private var buttonTitle: String {
        switch viewModel.state {
        case .loading:
            return localized("ios.action.fetching")
        default:
            return localized("ios.action.fetch_manifest")
        }
    }

    private var primaryReadinessButtonTitle: String {
        switch viewModel.readiness.primaryAction {
        case .pairAndroid:
            return localized("ios.action.scan_pairing_qr")
        case .enterEndpoint:
            return localized("ios.action.review_connection")
        case .allowPhotos:
            return localized("ios.action.allow_photos")
        case .waitForTransfer:
            return primarySyncButtonTitle
        case .fetchManifest:
            return buttonTitle
        case .syncAllPhotos:
            return primarySyncButtonTitle
        }
    }

    private var primaryReadinessButtonIcon: String {
        switch viewModel.readiness.primaryAction {
        case .pairAndroid:
            return "qrcode.viewfinder"
        case .enterEndpoint:
            return "network"
        case .allowPhotos:
            return "photo.badge.checkmark"
        case .waitForTransfer:
            return "hourglass"
        case .fetchManifest:
            return "arrow.clockwise"
        case .syncAllPhotos:
            return "arrow.triangle.2.circlepath"
        }
    }

    private var nextStepIconName: String {
        switch viewModel.readiness.nextStep {
        case .scanAndroidQRCode:
            return "qrcode.viewfinder"
        case .reviewAndroidEndpoint:
            return "wifi.exclamationmark"
        case .allowIPhonePhotos:
            return "photo.badge.checkmark"
        case .keepShareSyncOpen:
            return "hourglass"
        case .fetchLatestManifest:
            return "arrow.clockwise"
        case .syncRemainingPhotos:
            return "arrow.triangle.2.circlepath"
        }
    }

    private var primaryReadinessActionEnabled: Bool {
        switch viewModel.readiness.primaryAction {
        case .pairAndroid, .enterEndpoint:
            return true
        case .allowPhotos:
            return !viewModel.isTransferActive
        case .waitForTransfer:
            return false
        case .fetchManifest:
            return viewModel.canFetch
        case .syncAllPhotos:
            return viewModel.canSyncAll
        }
    }

    private var primarySyncButtonTitle: String {
        switch viewModel.downloadState {
        case .downloading:
            return localized("ios.action.syncing_photos")
        case .importing:
            return localized("ios.action.importing_photos")
        case .cancelled:
            return localized("ios.action.resume_photo_sync")
        default:
            return localized("ios.action.sync_all_photos")
        }
    }

    private func performPrimaryReadinessAction() {
        switch viewModel.readiness.primaryAction {
        case .pairAndroid:
            isShowingPairingScanner = true
        case .enterEndpoint:
            isSettingsExpanded = true
        case .allowPhotos:
            viewModel.syncAllPhotos()
        case .waitForTransfer:
            break
        case .fetchManifest:
            viewModel.fetchManifest()
        case .syncAllPhotos:
            viewModel.syncAllPhotos()
        }
    }

    private var summarySubtitle: String {
        if let summary = viewModel.summary {
            switch summary.transferStatus {
            case "Complete":
                return localized("ios.summary.all_complete")
            case "Needs Retry":
                return localized("ios.summary.retry_required")
            case "No Photos":
                return localized("ios.summary.no_photos")
            default:
                return String(format: localized("ios.summary.remaining_format"), "\(summary.remainingCount)")
            }
        }

        if viewModel.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localized("ios.summary.pair_to_begin")
        }

        return localized("ios.summary.fetch_latest")
    }

    private var nextStepText: String {
        switch viewModel.readiness.nextStep {
        case .scanAndroidQRCode:
            return localized("ios.next_step.pair_android")
        case .reviewAndroidEndpoint:
            return localized("ios.next_step.review_connection")
        case .allowIPhonePhotos:
            return localized("ios.next_step.allow_photos")
        case .keepShareSyncOpen:
            return localized("ios.next_step.keep_open")
        case .fetchLatestManifest:
            return localized("ios.next_step.fetch_manifest")
        case .syncRemainingPhotos:
            return localized("ios.next_step.sync_all")
        }
    }

    private var readinessReasonText: String? {
        switch viewModel.readiness.blockingReason {
        case .pairingRequired:
            return localized("ios.readiness.pairing_required")
        case .endpointMissing:
            return localized("ios.readiness.endpoint_missing")
        case .invalidPort:
            return localized("ios.readiness.invalid_port")
        case .transferActive:
            return localized("ios.readiness.transfer_active")
        case .photosPermissionBlocked:
            return localized("ios.readiness.photos_permission_blocked")
        case nil:
            return nil
        }
    }

    private var summaryIconName: String {
        switch phaseKind {
        case .transferComplete:
            return "checkmark.circle.fill"
        case .retryRequired, .transferError, .fetchError:
            return "exclamationmark.triangle.fill"
        case .transferActive, .fetchingManifest:
            return "arrow.triangle.2.circlepath"
        default:
            return "photo.on.rectangle.angled"
        }
    }

    private var summaryTone: ShareSyncTone {
        switch phaseKind {
        case .transferComplete:
            return .success
        case .retryRequired, .transferError, .fetchError:
            return .warning
        case .transferActive, .fetchingManifest:
            return .primary
        default:
            return .neutral
        }
    }

    private var pairedStatus: String {
        viewModel.host.isEmpty ? localized("ios.status.manual") : "\(viewModel.host):\(viewModel.port)"
    }

    private var bindingStatusText: String {
        if let pairedDevice = viewModel.pairedDevice {
            return String(format: localized("ios.value.remembered_binding_format"), pairedDevice.deviceName)
        }

        if !viewModel.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localized("ios.value.manual_endpoint_binding")
        }

        return localized("ios.value.no_binding")
    }

    private var phaseStatus: String {
        switch phaseKind {
        case .transferActive:
            return localized("ios.phase.transfer_active")
        case .fetchingManifest:
            return localized("ios.phase.fetching_manifest")
        case .fetchError:
            return localized("ios.phase.fetch_error")
        case .transferError:
            return localized("ios.phase.transfer_error")
        case .retryRequired:
            return localized("ios.phase.retry_required")
        case .pairingRequired:
            return localized("ios.phase.pairing_required")
        case .readyToFetch:
            return localized("ios.phase.ready_to_fetch")
        case .transferComplete:
            return localized("ios.phase.transfer_complete")
        case .noPhotos:
            return localized("ios.phase.no_photos")
        case .readyToTransfer:
            return localized("ios.phase.ready_to_transfer")
        }
    }

    private var phaseKind: PhaseKind {
        if viewModel.isTransferActive {
            return .transferActive
        }

        if case .loading = viewModel.state {
            return .fetchingManifest
        }

        if case .failed = viewModel.state {
            return .fetchError
        }

        if case .failed = viewModel.downloadState {
            return .transferError
        }

        if case .cancelled = viewModel.downloadState {
            return .retryRequired
        }

        if viewModel.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .pairingRequired
        }

        guard let summary = viewModel.summary else {
            return .readyToFetch
        }

        switch summary.transferStatus {
        case "Complete":
            return .transferComplete
        case "Needs Retry":
            return .retryRequired
        case "No Photos":
            return .noPhotos
        default:
            return .readyToTransfer
        }
    }

    private var manifestStatus: String {
        switch viewModel.state {
        case .idle:
            return localized("ios.status.ready")
        case .loading:
            return localized("ios.status.loading")
        case .loaded:
            return String(format: localized("ios.value.photo_count_format"), "\(viewModel.summary?.photoCount ?? 0)")
        case .failed:
            return localized("ios.status.failed")
        }
    }

    private var photosAccessStatus: String {
        switch viewModel.photoLibraryPermissionStatus {
        case .authorized:
            return localized("ios.status.allowed")
        case .limited:
            return localized("ios.status.limited")
        case .denied:
            return localized("ios.status.denied")
        case .restricted:
            return localized("ios.status.restricted")
        case .notDetermined:
            return localized("ios.status.not_asked")
        case .unknown:
            return localized("ios.status.unknown")
        }
    }

    private var screenLockStatus: String {
        shouldKeepScreenAwake(for: viewModel.downloadState) ? localized("ios.status.paused") : localized("ios.status.normal")
    }

    private var latestSyncText: String {
        guard let event = viewModel.latestSyncEvent else {
            return localized("ios.status.waiting")
        }

        return String(
            format: localized("ios.value.last_sync_format"),
            relativeDateFormatter.localizedString(for: event.recordedAt, relativeTo: Date()),
            "\(event.successfulCount)",
            "\(event.failedCount)"
        )
    }

    private var recentSyncHistoryText: String {
        viewModel.recentSyncHistory
            .map { summary in
                let batch = summary.syncBatchId ?? localized("ios.value.none")
                return String(
                    format: localized("ios.value.sync_history_item_format"),
                    batch,
                    "\(summary.successfulCount)",
                    "\(summary.failedCount)"
                )
            }
            .joined(separator: "\n")
    }

    private func lastFailureText(code: String, fileName: String?) -> String {
        guard let fileName, !fileName.isEmpty else {
            return code
        }
        return "\(code) - \(fileName)"
    }

    private func syncResultReturnText(_ summary: ManifestFetchViewModel.SyncResultReturnSummary) -> String {
        if let httpStatusCode = summary.httpStatusCode {
            return "\(summary.status) HTTP \(httpStatusCode)"
        }

        return summary.status
    }

    private func androidPeerText(_ health: LocalPeerHealth) -> String {
        String(format: localized("ios.value.ready_device_format"), health.deviceId, "\(health.protocolVersion)")
    }

    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }

    private func copySyncResult() {
        guard let json = viewModel.latestSyncResultJSON else {
            return
        }

        UIPasteboard.general.string = json
        syncResultCopyMessage = localized("ios.toast.sync_result_copied")
    }

    private func copyDiagnosticsSummary() {
        UIPasteboard.general.string = diagnosticsSummary()
        syncResultCopyMessage = localized("ios.toast.diagnostics_copied")
    }

    private func diagnosticsSummary() -> String {
        let summary = viewModel.summary
        let progress = viewModel.downloadProgressSummary
        let snapshot: [String: Any] = [
            "schemaVersion": 1,
            "type": "sharesync_support_snapshot",
            "platform": "ios",
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "appVersion": appVersionText,
            "phase": phaseStatus,
            "nextStep": supportSnapshotNextStep,
            "transport": viewModel.pairedDevice?.transportSecurity?.mode.rawValue ?? "signed_http",
            "endpoint": pairedStatus,
            "binding": bindingStatusText,
            "permissions": [
                "photos": photosAccessStatus,
            ],
            "ios": [
                "screenLock": screenLockStatus,
                "manifest": manifestStatus,
                "batchProgress": progress?.progressText ?? "none",
                "syncResultReturn": viewModel.syncResultReturnSummary.map(syncResultReturnText) ?? localized("ios.vm.not_posted"),
            ],
            "sync": [
                "photoCount": summary?.photoCount ?? 0,
                "remaining": summary?.remainingCount ?? 0,
                "downloaded": summary?.downloadedCount ?? 0,
                "imported": summary?.importedCount ?? 0,
                "failed": summary?.failedCount ?? 0,
                "partial": summary?.partialCount ?? 0,
            ],
            "redaction": [
                "pairingToken": "excluded",
                "requestSignature": "excluded",
                "sharedSecret": "excluded",
            ],
        ]

        guard JSONSerialization.isValidJSONObject(snapshot),
              let data = try? JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (version, build) {
        case let (.some(version), .some(build)):
            return "\(version) (\(build))"
        case let (.some(version), .none):
            return version
        default:
            return localized("ios.status.unknown")
        }
    }

    private var supportSnapshotNextStep: String {
        switch viewModel.readiness.nextStep {
        case .scanAndroidQRCode:
            return "scan_android_qr"
        case .reviewAndroidEndpoint:
            return "review_android_endpoint"
        case .allowIPhonePhotos:
            return "allow_iphone_photos"
        case .keepShareSyncOpen:
            return "keep_sharesync_open"
        case .fetchLatestManifest:
            return "fetch_latest_manifest"
        case .syncRemainingPhotos:
            return "sync_remaining_photos"
        }
    }

    private func updateIdleTimer(for state: ManifestFetchViewModel.DownloadState) {
        UIApplication.shared.isIdleTimerDisabled = shouldKeepScreenAwake(for: state)
    }

    private func shouldKeepScreenAwake(for state: ManifestFetchViewModel.DownloadState) -> Bool {
        state == .downloading || state == .importing
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func localizedTransferStatus(_ status: String) -> String {
        switch status {
        case "Complete":
            return localized("ios.phase.transfer_complete")
        case "Needs Retry":
            return localized("ios.phase.retry_required")
        case "No Photos":
            return localized("ios.phase.no_photos")
        default:
            return localized("ios.status.ready")
        }
    }
}

private enum AppTab {
    case receive
    case activity
    case settings
}

private enum PhaseKind {
    case fetchError
    case fetchingManifest
    case noPhotos
    case pairingRequired
    case readyToFetch
    case readyToTransfer
    case retryRequired
    case transferActive
    case transferComplete
    case transferError
}

private enum DestructiveAction {
    case forgetPhone
    case resetHistory
}

private enum ShareSyncTone {
    case primary
    case success
    case warning
    case error
    case info
    case neutral

    var color: Color {
        switch self {
        case .primary:
            return ShareSyncTheme.primary
        case .success:
            return ShareSyncTheme.success
        case .warning:
            return ShareSyncTheme.warning
        case .error:
            return ShareSyncTheme.error
        case .info:
            return ShareSyncTheme.info
        case .neutral:
            return .secondary
        }
    }

    var softBackground: Color {
        color.opacity(0.12)
    }

    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        case .info, .primary, .neutral:
            return "info.circle.fill"
        }
    }
}

private enum ShareSyncTheme {
    static let primary = adaptive(light: 0x2563EB, dark: 0x60A5FA)
    static let success = adaptive(light: 0x16803A, dark: 0x4ADE80)
    static let warning = adaptive(light: 0xB45309, dark: 0xFBBF24)
    static let error = adaptive(light: 0xB91C1C, dark: 0xF87171)
    static let info = adaptive(light: 0x0E7490, dark: 0x22D3EE)
    static let background = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let divider = Color.secondary.opacity(0.18)

    private static func adaptive(light: Int, dark: Int) -> Color {
        Color(
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private struct FeedbackMessage: View {
    let message: String
    let tone: ShareSyncTone

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tone.iconName)
                .foregroundStyle(tone.color)
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tone.softBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.color.opacity(0.24), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct StatusRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .fontWeight(.medium)
                Spacer(minLength: 8)
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ShareSyncTheme.divider)
                .frame(height: 1)
        }
    }
}

private struct ProductPanel<Content: View>: View {
    let title: LocalizedStringKey?
    let content: Content

    init(title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ShareSyncTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ShareSyncTheme.divider, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MetricView: View {
    let title: LocalizedStringKey
    let value: String
    let tone: ShareSyncTone

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(tone.color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(tone.softBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.color.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
}
