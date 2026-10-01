import SwiftUI

struct MacContentView: View {
    private enum Section: String {
        case photos
        case messages
    }

    @EnvironmentObject private var model: MacPhotoSyncViewModel
    @EnvironmentObject private var messageModel: MessageBridgePermissionViewModel
    @State private var showingPairing = false
    @State private var confirmUnpair = false
    @State private var isSidebarVisible = true
    @State private var selectedSection: Section = .photos

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .frame(width: 260)

                Divider()
            }

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(MacBrand.canvas)
        .sheet(isPresented: $showingPairing) {
            PairingSheet(isPresented: $showingPairing)
                .environmentObject(model)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    isSidebarVisible.toggle()
                } label: {
                    Label(sidebarToggleTitle, systemImage: "sidebar.leading")
                }
                .help(sidebarToggleTitle)
            }

            ToolbarItemGroup {
                if selectedSection == .photos {
                    Button {
                        model.refreshPhotos()
                    } label: {
                        Label("mac.action.refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(!model.isPaired || model.isBusy)
                    .help("mac.action.refresh")

                    if model.canCancel {
                        Button(role: .cancel) {
                            model.cancel()
                        } label: {
                            Label("mac.action.stop", systemImage: "stop.fill")
                        }
                        .help("mac.action.stop")
                    }
                } else {
                    Button {
                        messageModel.checkAccess()
                    } label: {
                        Label("bridge.action.check", systemImage: "checkmark.shield")
                    }
                    .disabled(messageModel.state == .checking)
                    .help("bridge.action.check")
                }
            }
        }
        .onAppear {
            if model.isPaired {
                model.refreshPhotos()
            }
        }
        .onChange(of: selectedSection) { section in
            if section == .messages {
                messageModel.checkAccess()
            }
        }
        .confirmationDialog("mac.unpair.confirm", isPresented: $confirmUnpair) {
            Button("mac.action.unpair", role: .destructive) {
                model.forgetDevice()
                showingPairing = true
            }
        }
    }

    private var sidebarToggleTitle: LocalizedStringKey {
        isSidebarVisible ? "mac.action.hide_sidebar" : "mac.action.show_sidebar"
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Label("ShareSync", systemImage: "arrow.left.arrow.right.circle.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(MacBrand.bridge)
                Text("mac.sidebar.subtitle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("mac.sidebar.features")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                sidebarItem(
                    title: "mac.sidebar.photos",
                    systemImage: "photo.on.rectangle.angled",
                    section: .photos
                )
                sidebarItem(
                    title: "mac.sidebar.messages",
                    systemImage: "message.fill",
                    section: .messages
                )
            }
            .padding(14)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("mac.sidebar.android")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let device = model.pairedDevice {
                    HStack(spacing: 10) {
                        Image(systemName: "smartphone")
                            .frame(width: 28, height: 28)
                            .background(MacBrand.handoff.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(MacBrand.handoff)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.deviceName)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Text(model.host)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text("mac.sidebar.not_paired")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showingPairing = true
                } label: {
                    Label(model.isPaired ? "mac.action.replace_device" : "mac.action.pair", systemImage: "qrcode")
                }
                .buttonStyle(.link)

                if model.isPaired {
                    Button(role: .destructive) {
                        confirmUnpair = true
                    } label: {
                        Label("mac.action.unpair", systemImage: "trash")
                    }
                    .buttonStyle(.link)
                    .disabled(model.isBusy)
                }
            }
            .padding(20)

            Spacer()

            VStack(alignment: .leading, spacing: 7) {
                Label("mac.sidebar.private", systemImage: "lock.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MacBrand.vault)
                Text("mac.sidebar.private_detail")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func sidebarItem(
        title: LocalizedStringKey,
        systemImage: String,
        section: Section
    ) -> some View {
        Button {
            selectedSection = section
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedSection == section ? MacBrand.bridge : .primary)
        .background(
            selectedSection == section ? MacBrand.bridge.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        switch selectedSection {
        case .photos:
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    statusHeader
                    photoOverview
                    transferProgress
                    primaryAction
                    completionReturnStatus
                    syncHistory
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(38)
            }
        case .messages:
            ScrollView {
                MessageBridgePermissionView()
                    .environmentObject(messageModel)
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.vertical, 10)
            }
        }
    }

    private var statusHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: statusSymbol)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 44, height: 44)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(model.statusTitle)
                    .font(.title2.weight(.semibold))
                Text(model.statusDetail)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var photoOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("mac.photos.title")
                .font(.headline)

            HStack(spacing: 0) {
                MetricView(value: model.photoCount, label: "mac.photos.available")
                Divider().frame(height: 44)
                MetricView(value: model.importedCount, label: "mac.photos.saved")
                Divider().frame(height: 44)
                MetricView(value: model.remainingCount, label: "mac.photos.remaining")
            }
            .padding(.vertical, 18)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator.opacity(0.7), lineWidth: 1)
            }
        }
    }

    private var primaryAction: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isPaired {
                HStack(spacing: 12) {
                    Button {
                        model.syncAllPhotos()
                    } label: {
                        Label("mac.action.sync_all", systemImage: "photo.stack.fill")
                            .frame(minWidth: 190)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(MacBrand.bridge)
                    .disabled(model.isBusy || model.remainingCount == 0)

                    Button {
                        model.syncNextPhoto()
                    } label: {
                        Label("mac.action.sync_next", systemImage: "photo.badge.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(model.isBusy || model.remainingCount == 0)
                }

                Text("mac.action.sync_all_detail")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    showingPairing = true
                } label: {
                    Label("mac.action.pair_android", systemImage: "qrcode.viewfinder")
                        .frame(minWidth: 190)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(MacBrand.bridge)

                Text("mac.action.pair_detail")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var transferProgress: some View {
        if let batch = model.batchProgress {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("mac.progress.title")
                        .font(.headline)
                    Spacer()
                    Text("\(batch.processedCount) / \(batch.totalCount)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(
                    value: Double(batch.processedCount),
                    total: Double(max(batch.totalCount, 1))
                )
                .tint(MacBrand.bridge)
                if let fileName = batch.currentFileName {
                    Text(fileName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if batch.failedCount > 0 {
                    HStack(spacing: 5) {
                        Text("mac.progress.failed")
                        Text(batch.failedCount.formatted())
                    }
                    .font(.callout)
                    .foregroundStyle(MacBrand.handoff)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var completionReturnStatus: some View {
        switch model.completionReturnState {
        case .none:
            EmptyView()
        case .delivered(let date):
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MacBrand.vault)
                VStack(alignment: .leading, spacing: 2) {
                    Text("mac.return.delivered")
                        .fontWeight(.medium)
                    Text("mac.return.delivered_detail")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(date, style: .relative)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        case .pendingRetry(_, let errorCode):
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                    .foregroundStyle(MacBrand.handoff)
                VStack(alignment: .leading, spacing: 2) {
                    Text("mac.return.pending")
                        .fontWeight(.medium)
                    Text("mac.return.pending_detail")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(errorCode)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("mac.return.retry") {
                    model.refreshPhotos()
                }
                .disabled(model.isBusy || !model.isPaired)
            }
            .padding(14)
            .background(MacBrand.handoff.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var syncHistory: some View {
        if !model.recentSyncHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("mac.history.title")
                    .font(.headline)

                ForEach(model.recentSyncHistory) { summary in
                    HStack(spacing: 12) {
                        Image(systemName: summary.needsRetry ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(summary.needsRetry ? MacBrand.handoff : MacBrand.vault)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(summary.needsRetry ? "mac.history.attention" : "mac.history.complete")
                                .fontWeight(.medium)
                            HStack(spacing: 5) {
                                Text("mac.history.saved")
                                Text(summary.successfulCount.formatted())
                                Text("mac.history.separator")
                                Text("mac.history.retry")
                                Text(summary.failedCount.formatted())
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(summary.recordedAt, style: .relative)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 7)
                }
            }
        }
    }

    private var statusColor: Color {
        switch model.phase {
        case .failed: return MacBrand.handoff
        case .completed: return MacBrand.vault
        default: return MacBrand.bridge
        }
    }

    private var statusSymbol: String {
        switch model.phase {
        case .failed: return "exclamationmark.triangle.fill"
        case .completed: return "checkmark.circle.fill"
        case .downloading, .importing: return "arrow.down.circle.fill"
        default: return model.isPaired ? "link.circle.fill" : "qrcode"
        }
    }
}

private struct MetricView: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value.formatted())
                .font(.title2.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }
}

private struct PairingSheet: View {
    @EnvironmentObject private var model: MacPhotoSyncViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(systemName: "qrcode.viewfinder")
                    .font(.title)
                    .foregroundStyle(MacBrand.handoff)
                VStack(alignment: .leading, spacing: 3) {
                    Text("mac.pair.title")
                        .font(.title2.weight(.semibold))
                    Text("mac.pair.scan_subtitle")
                        .foregroundStyle(.secondary)
                }
            }

            Group {
                if let payload = model.pairingQRCodePayload {
                    MacQRCodeView(payload: payload)
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ProgressView("mac.pair.preparing")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 250, height: 250)
            .frame(maxWidth: .infinity)

            Text("mac.pair.scan_hint")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(
                    systemName: model.nearbyAndroidDevices.isEmpty
                        ? "dot.radiowaves.left.and.right"
                        : "iphone.radiowaves.left.and.right"
                )
                    .foregroundStyle(model.nearbyAndroidDevices.isEmpty ? Color.secondary : MacBrand.vault)

                VStack(alignment: .leading, spacing: 2) {
                    if model.isDiscoveringNearbyDevices {
                        Text("mac.pair.nearby_searching")
                            .font(.callout.weight(.medium))
                    } else if let device = model.nearbyAndroidDevices.first {
                        Text(
                            String(
                                format: NSLocalizedString("mac.pair.nearby_found", comment: ""),
                                device.deviceName
                            )
                        )
                            .font(.callout.weight(.medium))
                        Text(LocalizedStringKey(
                            model.selectedNearbyAndroidDeviceID == device.deviceId
                                ? "mac.pair.nearby_selected"
                                : "mac.pair.nearby_untrusted"
                        ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("mac.pair.nearby_none")
                            .font(.callout.weight(.medium))
                        Text("mac.pair.nearby_none_detail")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let device = model.nearbyAndroidDevices.first {
                    Button {
                        model.beginMacPairing(with: device)
                    } label: {
                        if model.selectedNearbyAndroidDeviceID == device.deviceId {
                            Label("mac.pair.nearby_waiting", systemImage: "checkmark.circle.fill")
                        } else {
                            Text("mac.pair.nearby_pair")
                        }
                    }
                    .disabled(model.selectedNearbyAndroidDeviceID == device.deviceId)
                } else {
                    Button {
                        model.refreshNearbyDevices()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("mac.pair.nearby_refresh")
                    .disabled(model.isDiscoveringNearbyDevices)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))

            DisclosureGroup("mac.pair.manual") {
                TextEditor(text: $model.pairingPayload)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 90)
                    .background(.background, in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7).stroke(.separator, lineWidth: 1)
                    }

                Button("mac.pair.apply_manual") {
                    model.pair()
                    if model.isPaired { isPresented = false }
                }
                .disabled(model.pairingPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let message = model.failureMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(MacBrand.handoff)
            }

            HStack {
                Spacer()
                Button("mac.action.cancel") {
                    isPresented = false
                }
            }
        }
        .padding(28)
        .frame(width: 570)
        .task { model.beginMacPairing() }
        .onDisappear { model.stopMacPairing() }
        .onChange(of: model.isPaired) { paired in
            if paired { isPresented = false }
        }
    }
}

struct MacSettingsView: View {
    @EnvironmentObject private var model: MacPhotoSyncViewModel
    @EnvironmentObject private var launchAtLogin: LaunchAtLoginController
    @State private var confirmForget = false
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("mac.settings.automation") {
                Toggle("mac.settings.automatic_sync", isOn: $model.automaticSyncEnabled)

                Picker("mac.settings.interval", selection: $model.scheduledSyncIntervalMinutes) {
                    Text("mac.settings.interval.5").tag(5)
                    Text("mac.settings.interval.15").tag(15)
                    Text("mac.settings.interval.30").tag(30)
                    Text("mac.settings.interval.60").tag(60)
                }
                .disabled(!model.automaticSyncEnabled)

                Picker("mac.settings.batch", selection: $model.scheduledBatchLimit) {
                    Text("mac.settings.batch.25").tag(25)
                    Text("mac.settings.batch.50").tag(50)
                    Text("mac.settings.batch.100").tag(100)
                    Text("mac.settings.batch.all").tag(0)
                }
                .disabled(!model.automaticSyncEnabled)

                if let date = model.nextScheduledSyncAt, model.automaticSyncEnabled {
                    LabeledContent("mac.settings.next_sync") {
                        Text(date, style: .relative)
                    }
                }

                Toggle("mac.settings.keep_running", isOn: $model.keepRunning)
                Text("mac.settings.keep_running_detail")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(
                    "mac.settings.launch_at_login",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                Text("mac.settings.launch_at_login_detail")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if launchAtLogin.requiresApproval {
                    LabeledContent("mac.settings.launch_at_login_status") {
                        Button("mac.settings.open_login_items") {
                            launchAtLogin.openLoginItemsSettings()
                        }
                    }
                }

                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("mac.settings.connection") {
                TextField("mac.settings.host", text: $model.host)
                TextField("mac.settings.port", text: $model.port)
            }

            Section("mac.settings.storage") {
                LabeledContent("mac.settings.destination", value: String(localized: "mac.settings.photos_value"))
                Button("mac.settings.reset_history", role: .destructive) {
                    confirmReset = true
                }
                .disabled(model.isBusy)
            }

            Section {
                Button("mac.settings.forget", role: .destructive) {
                    confirmForget = true
                }
                .disabled(!model.isPaired || model.isBusy)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { launchAtLogin.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
        .confirmationDialog("mac.settings.forget_confirm", isPresented: $confirmForget) {
            Button("mac.settings.forget", role: .destructive) { model.forgetDevice() }
        }
        .confirmationDialog("mac.settings.reset_confirm", isPresented: $confirmReset) {
            Button("mac.settings.reset_history", role: .destructive) { model.resetLocalHistory() }
        }
    }
}

private enum MacBrand {
    static let bridge = Color(red: 49 / 255, green: 89 / 255, blue: 198 / 255)
    static let handoff = Color(red: 200 / 255, green: 79 / 255, blue: 55 / 255)
    static let vault = Color(red: 25 / 255, green: 118 / 255, blue: 83 / 255)
    static let canvas = Color(nsColor: .windowBackgroundColor)
}
