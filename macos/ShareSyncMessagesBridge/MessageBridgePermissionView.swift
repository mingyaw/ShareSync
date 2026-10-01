import AppKit
import Network
import SwiftUI

@MainActor
final class MessageBridgePermissionViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case available(String)
        case permissionRequired
        case unavailable
        case unsupported([String])
        case failed(Int32)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var validationState: ValidationState = .inactive
    @Published var previewSenderIdentifier = ""
    @Published private(set) var previewState: PreviewState = .inactive
    @Published var telegramTokenDraft = ""
    @Published var telegramChatID = ""
    @Published var telegramAllowedSender = ""
    @Published private(set) var telegramState: TelegramState = .unconfigured
    @Published private(set) var telegramResult: MessageForwardingRunResult?
    @Published private(set) var isTelegramAutoForwarding = false
    @Published private(set) var telegramReplyState: TelegramReplyState = .disabled
    @Published private(set) var telegramReplyResult: TelegramReplyRunResult?
    @Published private(set) var isTelegramReplyEnabled = false

    private let telegramSettingsStore = TelegramBotSettingsStore()
    private let telegramRateLimiter = MessageDeliveryRateLimiter(
        maximumDeliveries: 20,
        interval: 60
    )
    private var telegramPollingTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?
    private var isMonitoringNetwork = false
    private var wasNetworkSatisfied: Bool?
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "com.sharesync.message-recovery")

    enum ValidationState: Equatable {
        case inactive
        case establishing
        case ready
        case checking
        case empty
        case result(MessageValidationSummary)
        case failed
    }

    enum PreviewState: Equatable {
        case inactive
        case establishing
        case ready
        case needsSender
        case running
        case result(MessageForwardingRunResult)
        case failed
    }

    enum TelegramState: Equatable {
        case unconfigured
        case saved
        case testing
        case ready
        case baselineRequired
        case forwarding
        case forwarded
        case invalidConfiguration
        case failed
    }

    enum TelegramReplyState: Equatable {
        case disabled
        case establishing
        case ready
        case checking
        case sent
        case noReplies
        case privateChatRequired
        case automationPermissionRequired
        case recipientUnavailable
        case failed
    }

    init() {
        let settings = telegramSettingsStore.loadSettings()
        telegramChatID = settings.chatID
        telegramAllowedSender = settings.allowedSenderIdentifier
        if (try? telegramSettingsStore.loadToken()) != nil, !settings.chatID.isEmpty {
            telegramState = .saved
        }
    }

    func startRuntimeObservation() {
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recoverTelegramAutomation()
                }
            }
        }

        guard !isMonitoringNetwork else { return }
        isMonitoringNetwork = true
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let isSatisfied = path.status == .satisfied
                let shouldRecover = self.wasNetworkSatisfied == false && isSatisfied
                self.wasNetworkSatisfied = isSatisfied
                if shouldRecover {
                    self.recoverTelegramAutomation()
                }
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
    }

    var titleKey: LocalizedStringKey {
        switch state {
        case .idle: return "bridge.status.not_checked"
        case .checking: return "bridge.status.checking"
        case .available: return "bridge.status.available"
        case .permissionRequired: return "bridge.status.permission_required"
        case .unavailable: return "bridge.status.unavailable"
        case .unsupported: return "bridge.status.unsupported"
        case .failed: return "bridge.status.failed"
        }
    }

    var detail: String {
        switch state {
        case .idle:
            return String(localized: "bridge.detail.not_checked")
        case .checking:
            return String(localized: "bridge.detail.checking")
        case .available(let fingerprint):
            return String(
                format: String(localized: "bridge.detail.available"),
                String(fingerprint.prefix(12))
            )
        case .permissionRequired:
            return String(localized: "bridge.detail.permission_required")
        case .unavailable:
            return String(localized: "bridge.detail.unavailable")
        case .unsupported(let missing):
            return String(
                format: String(localized: "bridge.detail.unsupported"),
                missing.prefix(4).joined(separator: ", ")
            )
        case .failed(let code):
            return String(format: String(localized: "bridge.detail.failed"), code)
        }
    }

    var symbol: String {
        switch state {
        case .available: return "checkmark.shield.fill"
        case .permissionRequired: return "lock.trianglebadge.exclamationmark.fill"
        case .unsupported, .failed: return "exclamationmark.triangle.fill"
        case .checking: return "ellipsis.circle.fill"
        case .idle, .unavailable: return "lock.shield.fill"
        }
    }

    func checkAccess() {
        guard state != .checking else { return }
        state = .checking
        let databaseURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Messages/chat.db")
        let status = MessageDatabaseAccessProbe().status(databaseURL: databaseURL)
        switch status {
        case .available(let fingerprint):
            state = .available(fingerprint)
            refreshValidationState()
            refreshPreviewState()
            resumeTelegramAutomationIfNeeded()
        case .permissionRequired:
            state = .permissionRequired
            validationState = .inactive
            previewState = .inactive
        case .unavailable:
            state = .unavailable
            validationState = .inactive
            previewState = .inactive
        case .unsupportedSchema(_, let missing):
            state = .unsupported(missing)
            validationState = .inactive
            previewState = .inactive
        case .failed(let code):
            state = .failed(code)
            validationState = .inactive
            previewState = .inactive
        }
    }

    func establishBaseline() {
        guard case .available = state, validationState != .establishing else { return }
        validationState = .establishing
        do {
            _ = try validationSession().activate()
            validationState = .ready
        } catch {
            validationState = .failed
        }
    }

    func checkControlledMessages() {
        guard case .available = state, validationState != .checking else { return }
        validationState = .checking
        do {
            let summary = try validationSession().poll { _ in }
            validationState = summary.isEmpty ? .empty : .result(summary)
        } catch MessageValidationSessionError.baselineRequired {
            validationState = .inactive
        } catch {
            validationState = .failed
        }
    }

    func establishPreviewBaseline() {
        guard case .available = state, previewState != .establishing else { return }
        previewState = .establishing
        do {
            _ = try ControlledMessageValidationSession(
                reader: messageReader(),
                cursorStore: previewCursorStore()
            ).activate()
            previewState = .ready
        } catch {
            previewState = .failed
        }
    }

    func runLocalPreview() {
        let sender = previewSenderIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sender.isEmpty else {
            previewState = .needsSender
            return
        }
        guard previewState != .running else { return }
        previewState = .running
        do {
            let pipeline = MessageForwardingPipeline(
                reader: messageReader(),
                cursorStore: previewCursorStore(),
                policy: MessageForwardingPolicy(allowedSenderIdentifiers: [sender]),
                connector: InMemoryMessageForwardingConnector(),
                deliveryLedger: previewDeliveryLedger(),
                rateLimiter: MessageDeliveryRateLimiter(maximumDeliveries: 30, interval: 60)
            )
            let result = try AuditedMessageForwardingRunner(
                pipeline: pipeline,
                auditStore: previewAuditStore()
            ).run()
            previewState = .result(result)
        } catch MessageValidationSessionError.baselineRequired {
            previewState = .inactive
        } catch {
            previewState = .failed
        }
    }

    func resetValidation() {
        do {
            try cursorStore().clear()
            validationState = .inactive
        } catch {
            validationState = .failed
        }
    }

    func resetPreview() {
        do {
            try previewCursorStore().clear()
            try previewDeliveryLedger().clear()
            try previewAuditStore().clear()
            previewSenderIdentifier = ""
            previewState = .inactive
        } catch {
            previewState = .failed
        }
    }

    func saveAndTestTelegram() {
        guard telegramState != .testing else { return }
        do {
            try persistTelegramConfiguration()
            let configuration = try telegramConfiguration()
            telegramState = .testing
            Task {
                do {
                    try await Task.detached(priority: .userInitiated) {
                        try TelegramBotConnector(configuration: configuration).verifyDelivery()
                    }.value
                    telegramState = .ready
                } catch {
                    telegramState = .failed
                }
            }
        } catch {
            telegramState = .invalidConfiguration
        }
    }

    func establishTelegramBaseline() {
        guard case .available = state else { return }
        do {
            try persistTelegramConfiguration()
            _ = try ControlledMessageValidationSession(
                reader: messageReader(),
                cursorStore: telegramCursorStore()
            ).activate()
            telegramResult = nil
            telegramState = .ready
        } catch {
            telegramState = .invalidConfiguration
        }
    }

    func forwardTelegramNow() {
        guard case .available = state, telegramState != .forwarding else { return }
        do {
            try persistTelegramConfiguration()
            let configuration = try telegramConfiguration()
            let sender = telegramAllowedSender.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sender.isEmpty else {
                telegramState = .invalidConfiguration
                return
            }
            let reader = messageReader()
            let cursorStore = telegramCursorStore()
            let deliveryLedger = telegramDeliveryLedger()
            let auditStore = telegramAuditStore()
            let replyRouteStore = telegramReplyRouteStore()
            let rateLimiter = telegramRateLimiter
            telegramState = .forwarding
            Task {
                do {
                    let result = try await Task.detached(priority: .utility) {
                        let pipeline = MessageForwardingPipeline(
                            reader: reader,
                            cursorStore: cursorStore,
                            policy: MessageForwardingPolicy(allowedSenderIdentifiers: [sender]),
                            connector: TelegramBotConnector(
                                configuration: configuration,
                                replyRouteStore: replyRouteStore
                            ),
                            deliveryLedger: deliveryLedger,
                            rateLimiter: rateLimiter,
                            envelopeBuilder: MessageConnectorEnvelopeBuilder(
                                senderLabels: [sender: sender]
                            )
                        )
                        return try AuditedMessageForwardingRunner(
                            pipeline: pipeline,
                            auditStore: auditStore
                        ).run(limit: 50)
                    }.value
                    telegramResult = result
                    telegramState = .forwarded
                } catch MessageValidationSessionError.baselineRequired {
                    telegramState = .baselineRequired
                    setTelegramAutoForwarding(false)
                } catch {
                    telegramState = .failed
                }
            }
        } catch {
            telegramState = .invalidConfiguration
        }
    }

    func setTelegramAutoForwarding(_ enabled: Bool) {
        guard enabled != isTelegramAutoForwarding else { return }
        telegramPollingTask?.cancel()
        telegramPollingTask = nil
        guard enabled else {
            isTelegramAutoForwarding = false
            telegramSettingsStore.setAutomaticForwardingEnabled(false)
            return
        }
        do {
            try persistTelegramConfiguration()
            guard !telegramAllowedSender.isEmpty else {
                telegramState = .invalidConfiguration
                return
            }
            guard try telegramCursorStore().load() != nil else {
                telegramState = .baselineRequired
                return
            }
        } catch {
            telegramState = .invalidConfiguration
            return
        }
        isTelegramAutoForwarding = true
        telegramSettingsStore.setAutomaticForwardingEnabled(true)
        telegramPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.forwardTelegramNow()
                if self?.isTelegramReplyEnabled == true {
                    self?.checkTelegramReplies()
                }
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func enableTelegramReplies() {
        guard telegramReplyState != .establishing else { return }
        do {
            try persistTelegramConfiguration()
            let configuration = try telegramConfiguration()
            guard let chatID = Int64(telegramChatID), chatID > 0 else {
                telegramReplyState = .privateChatRequired
                return
            }
            let cursorStore = telegramUpdateCursorStore()
            let processor = telegramReplyProcessor(
                configuration: configuration,
                authorizedPrivateChatID: String(chatID),
                cursorStore: cursorStore
            )
            telegramReplyState = .establishing
            Task {
                do {
                    if !cursorStore.hasStoredCursor {
                        try await Task.detached(priority: .userInitiated) {
                            try processor.establishBaseline()
                        }.value
                    }
                    isTelegramReplyEnabled = true
                    telegramSettingsStore.setRepliesEnabled(true)
                    telegramReplyState = .ready
                } catch {
                    isTelegramReplyEnabled = false
                    telegramReplyState = .failed
                }
            }
        } catch {
            telegramReplyState = .failed
        }
    }

    func checkTelegramReplies() {
        guard isTelegramReplyEnabled, telegramReplyState != .checking else { return }
        do {
            let configuration = try telegramConfiguration()
            guard let chatID = Int64(telegramChatID), chatID > 0 else {
                telegramReplyState = .privateChatRequired
                isTelegramReplyEnabled = false
                return
            }
            let processor = telegramReplyProcessor(
                configuration: configuration,
                authorizedPrivateChatID: String(chatID),
                cursorStore: telegramUpdateCursorStore()
            )
            telegramReplyState = .checking
            Task {
                do {
                    let result = try await Task.detached(priority: .utility) {
                        try processor.run()
                    }.value
                    telegramReplyResult = result
                    telegramReplyState = result.sentCount > 0 ? .sent : .noReplies
                } catch MessagesAutomationSender.AutomationError.permissionDenied {
                    telegramReplyState = .automationPermissionRequired
                } catch MessagesAutomationSender.AutomationError.recipientUnavailable {
                    telegramReplyState = .recipientUnavailable
                } catch {
                    telegramReplyState = .failed
                }
            }
        } catch {
            telegramReplyState = .failed
        }
    }

    func disableTelegramReplies() {
        isTelegramReplyEnabled = false
        telegramSettingsStore.setRepliesEnabled(false)
        telegramReplyResult = nil
        telegramReplyState = .disabled
    }

    func resetTelegram() {
        setTelegramAutoForwarding(false)
        do {
            try telegramSettingsStore.clear()
            try telegramCursorStore().clear()
            try telegramDeliveryLedger().clear()
            try telegramAuditStore().clear()
            try telegramReplyRouteStore().clear()
            try telegramUpdateCursorStore().clear()
            telegramTokenDraft = ""
            telegramChatID = ""
            telegramAllowedSender = ""
            telegramResult = nil
            telegramReplyResult = nil
            isTelegramReplyEnabled = false
            telegramReplyState = .disabled
            telegramState = .unconfigured
        } catch {
            telegramState = .failed
        }
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openAutomationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshValidationState() {
        do {
            validationState = try cursorStore().load() == nil ? .inactive : .ready
        } catch {
            validationState = .failed
        }
    }

    private func validationSession() -> ControlledMessageValidationSession {
        return ControlledMessageValidationSession(
            reader: messageReader(),
            cursorStore: cursorStore()
        )
    }

    private func messageReader() -> MessageEventReader {
        MessageEventReader(
            databaseURL: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Messages/chat.db")
        )
    }

    private func cursorStore() -> FileMessageCursorStore {
        FileMessageCursorStore(
            fileURL: bridgeSupportDirectory().appendingPathComponent("validation-cursor.json")
        )
    }

    private func refreshPreviewState() {
        do {
            previewState = try previewCursorStore().load() == nil ? .inactive : .ready
        } catch {
            previewState = .failed
        }
    }

    private func previewCursorStore() -> FileMessageCursorStore {
        FileMessageCursorStore(
            fileURL: bridgeSupportDirectory().appendingPathComponent("preview-cursor.json")
        )
    }

    private func previewDeliveryLedger() -> FileMessageDeliveryLedgerStore {
        FileMessageDeliveryLedgerStore(
            fileURL: bridgeSupportDirectory().appendingPathComponent("preview-delivery-ledger.json")
        )
    }

    private func previewAuditStore() -> FileMessageForwardingAuditStore {
        FileMessageForwardingAuditStore(
            fileURL: bridgeSupportDirectory().appendingPathComponent("preview-audit.json")
        )
    }

    private func persistTelegramConfiguration() throws {
        let chatID = telegramChatID.trimmingCharacters(in: .whitespacesAndNewlines)
        let sender = telegramAllowedSender.trimmingCharacters(in: .whitespacesAndNewlines)
        if !telegramTokenDraft.isEmpty {
            _ = try TelegramBotConfiguration(token: telegramTokenDraft, chatID: chatID)
            try telegramSettingsStore.saveToken(telegramTokenDraft)
            telegramTokenDraft = ""
        }
        _ = try telegramConfiguration(chatID: chatID)
        var settings = telegramSettingsStore.loadSettings()
        settings.chatID = chatID
        settings.allowedSenderIdentifier = sender
        telegramSettingsStore.saveSettings(settings)
        telegramChatID = chatID
        telegramAllowedSender = sender
    }

    private func telegramConfiguration(chatID: String? = nil) throws -> TelegramBotConfiguration {
        guard let token = try telegramSettingsStore.loadToken() else {
            throw TelegramBotConnectorError.invalidToken
        }
        return try TelegramBotConfiguration(token: token, chatID: chatID ?? telegramChatID)
    }

    private func telegramCursorStore() -> FileMessageCursorStore {
        FileMessageCursorStore(
            fileURL: bridgeSupportDirectory().appendingPathComponent("telegram-cursor.json")
        )
    }

    private func telegramDeliveryLedger() -> FileMessageDeliveryLedgerStore {
        FileMessageDeliveryLedgerStore(
            fileURL: bridgeSupportDirectory().appendingPathComponent("telegram-delivery-ledger.json")
        )
    }

    private func telegramAuditStore() -> FileMessageForwardingAuditStore {
        FileMessageForwardingAuditStore(
            fileURL: bridgeSupportDirectory().appendingPathComponent("telegram-audit.json")
        )
    }

    private func telegramReplyRouteStore() -> FileTelegramReplyRouteStore {
        FileTelegramReplyRouteStore(
            fileURL: bridgeSupportDirectory().appendingPathComponent("telegram-reply-routes.json")
        )
    }

    private func telegramUpdateCursorStore() -> FileTelegramUpdateCursorStore {
        FileTelegramUpdateCursorStore(
            fileURL: bridgeSupportDirectory().appendingPathComponent("telegram-update-cursor.json")
        )
    }

    private func telegramReplyProcessor(
        configuration: TelegramBotConfiguration,
        authorizedPrivateChatID: String,
        cursorStore: FileTelegramUpdateCursorStore
    ) -> TelegramReplyProcessor {
        TelegramReplyProcessor(
            updates: TelegramBotUpdateClient(configuration: configuration),
            cursorStore: cursorStore,
            routeStore: telegramReplyRouteStore(),
            sender: MessagesAutomationSender(),
            authorizedPrivateChatID: authorizedPrivateChatID
        )
    }

    private func resumeTelegramAutomationIfNeeded() {
        let settings = telegramSettingsStore.loadSettings()
        if settings.repliesEnabled, !isTelegramReplyEnabled {
            enableTelegramReplies()
        }
        if settings.automaticForwardingEnabled, !isTelegramAutoForwarding {
            setTelegramAutoForwarding(true)
        }
    }

    private func recoverTelegramAutomation() {
        guard case .available = state, isTelegramAutoForwarding else { return }
        forwardTelegramNow()
        if isTelegramReplyEnabled {
            checkTelegramReplies()
        }
    }

    private func bridgeSupportDirectory() -> URL {
        let applicationSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = applicationSupport ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return root.appendingPathComponent("ShareSync/MessagesBridge", isDirectory: true)
    }
}

struct MessageBridgePermissionView: View {
    @EnvironmentObject private var model: MessageBridgePermissionViewModel
    @State private var resetTarget: ResetTarget?

    private enum ResetTarget: String, Identifiable {
        case validation
        case preview
        case telegram

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "message.badge.waveform.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("bridge.title")
                        .font(.title2.weight(.semibold))
                    Text("bridge.subtitle")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: model.symbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.titleKey)
                        .font(.headline)
                    Text(model.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("bridge.privacy.schema_only", systemImage: "checkmark.circle")
                Label("bridge.privacy.no_content", systemImage: "checkmark.circle")
                Label("bridge.privacy.explicit_network", systemImage: "checkmark.circle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            if case .available = model.state {
                Divider()
                validationSection
                Divider()
                previewSection
                Divider()
                telegramSection
            }

            HStack {
                if model.state == .permissionRequired {
                    Button("bridge.action.open_settings") {
                        model.openPrivacySettings()
                    }
                }

                Spacer()

                Button("bridge.action.check") {
                    model.checkAccess()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.state == .checking)
            }
        }
        .padding(28)
        .frame(width: 520)
        .confirmationDialog(
            resetDialogTitle,
            isPresented: Binding(
                get: { resetTarget != nil },
                set: { if !$0 { resetTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("bridge.reset.confirm", role: .destructive) {
                switch resetTarget {
                case .validation?: model.resetValidation()
                case .preview?: model.resetPreview()
                case .telegram?: model.resetTelegram()
                case nil: break
                }
            }
            Button("bridge.reset.cancel", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("bridge.validation.title")
                .font(.headline)

            Text(validationDetail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .result(let summary) = model.validationState {
                HStack(spacing: 18) {
                    validationMetric("bridge.validation.metric.total", value: summary.eventCount)
                    validationMetric("bridge.validation.metric.incoming", value: summary.incomingCount)
                    validationMetric("bridge.validation.metric.text", value: summary.plainTextCount)
                    validationMetric("bridge.validation.metric.attachments", value: summary.attachmentCount)
                }
            }

            HStack {
                if model.validationState == .inactive || model.validationState == .failed {
                    Button("bridge.action.establish_baseline") {
                        model.establishBaseline()
                    }
                    .disabled(model.validationState == .establishing)
                } else {
                    Button("bridge.action.check_messages") {
                        model.checkControlledMessages()
                    }
                    .disabled(model.validationState == .checking)
                }
                if model.validationState != .inactive {
                    Button("bridge.action.reset") {
                        resetTarget = .validation
                    }
                }
                Spacer()
            }
        }
    }

    private func validationMetric(_ key: LocalizedStringKey, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.title3.weight(.semibold))
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 72, alignment: .leading)
    }

    private var validationDetail: LocalizedStringKey {
        switch model.validationState {
        case .inactive: return "bridge.validation.inactive"
        case .establishing: return "bridge.validation.establishing"
        case .ready: return "bridge.validation.ready"
        case .checking: return "bridge.validation.checking"
        case .empty: return "bridge.validation.empty"
        case .result: return "bridge.validation.result"
        case .failed: return "bridge.validation.failed"
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("bridge.preview.title")
                .font(.headline)
            Text(previewDetail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("bridge.preview.sender.placeholder", text: $model.previewSenderIdentifier)
                .textFieldStyle(.roundedBorder)
                .disabled(model.previewState == .inactive || model.previewState == .establishing)

            if case .result(let result) = model.previewState {
                HStack(spacing: 18) {
                    validationMetric("bridge.preview.metric.inspected", value: result.inspectedCount)
                    validationMetric("bridge.preview.metric.matched", value: result.eligibleCount)
                    validationMetric("bridge.preview.metric.blocked", value: result.deniedCounts.values.reduce(0, +))
                }
            }

            HStack {
                if model.previewState == .inactive || model.previewState == .failed {
                    Button("bridge.preview.action.baseline") {
                        model.establishPreviewBaseline()
                    }
                } else {
                    Button("bridge.preview.action.run") {
                        model.runLocalPreview()
                    }
                    .disabled(model.previewState == .running || model.previewState == .establishing)
                }
                if model.previewState != .inactive {
                    Button("bridge.action.reset") {
                        resetTarget = .preview
                    }
                }
                Spacer()
                Text("bridge.preview.session_only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var previewDetail: LocalizedStringKey {
        switch model.previewState {
        case .inactive: return "bridge.preview.inactive"
        case .establishing: return "bridge.preview.establishing"
        case .ready: return "bridge.preview.ready"
        case .needsSender: return "bridge.preview.needs_sender"
        case .running: return "bridge.preview.running"
        case .result: return "bridge.preview.result"
        case .failed: return "bridge.preview.failed"
        }
    }

    @ViewBuilder
    private var telegramSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("bridge.telegram.title", systemImage: "paperplane.fill")
                    .font(.headline)
                Spacer()
                Text("bridge.telegram.keychain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(telegramDetail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("bridge.telegram.token.placeholder", text: $model.telegramTokenDraft)
                .textFieldStyle(.roundedBorder)
            TextField("bridge.telegram.chat_id.placeholder", text: $model.telegramChatID)
                .textFieldStyle(.roundedBorder)
            TextField("bridge.telegram.sender.placeholder", text: $model.telegramAllowedSender)
                .textFieldStyle(.roundedBorder)

            if let result = model.telegramResult {
                HStack(spacing: 18) {
                    validationMetric("bridge.preview.metric.inspected", value: result.inspectedCount)
                    validationMetric("bridge.telegram.metric.sent", value: result.deliveredCount)
                    validationMetric("bridge.preview.metric.blocked", value: result.deniedCounts.values.reduce(0, +))
                }
            }

            HStack {
                Button("bridge.telegram.action.test") {
                    model.saveAndTestTelegram()
                }
                .disabled(model.telegramState == .testing || model.telegramState == .forwarding)

                if model.telegramState == .baselineRequired || model.telegramState == .saved || model.telegramState == .ready {
                    Button("bridge.telegram.action.baseline") {
                        model.establishTelegramBaseline()
                    }
                }

                Button("bridge.telegram.action.forward") {
                    model.forwardTelegramNow()
                }
                .disabled(model.telegramState == .forwarding)

                Spacer()

                Toggle(
                    "bridge.telegram.auto",
                    isOn: Binding(
                        get: { model.isTelegramAutoForwarding },
                        set: { model.setTelegramAutoForwarding($0) }
                    )
                )
                .toggleStyle(.switch)
            }

            HStack {
                Text("bridge.telegram.auto.detail")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("bridge.action.reset", role: .destructive) {
                    resetTarget = .telegram
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrowshape.turn.up.left.circle.fill")
                    .foregroundStyle(model.isTelegramReplyEnabled ? .green : .secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text("bridge.telegram.reply.title")
                        .font(.subheadline.weight(.semibold))
                    Text(telegramReplyDetail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let result = model.telegramReplyResult {
                HStack(spacing: 18) {
                    validationMetric("bridge.telegram.reply.metric.checked", value: result.inspectedCount)
                    validationMetric("bridge.telegram.reply.metric.sent", value: result.sentCount)
                    validationMetric("bridge.telegram.reply.metric.ignored", value: result.ignoredCount)
                }
            }

            HStack {
                if model.isTelegramReplyEnabled {
                    Button("bridge.telegram.reply.action.check") {
                        model.checkTelegramReplies()
                    }
                    .disabled(model.telegramReplyState == .checking)
                    Button("bridge.telegram.reply.action.disable") {
                        model.disableTelegramReplies()
                    }
                } else {
                    Button("bridge.telegram.reply.action.enable") {
                        model.enableTelegramReplies()
                    }
                    .disabled(model.telegramReplyState == .establishing)
                }
                Spacer()
                if model.isTelegramReplyEnabled {
                    Label("bridge.telegram.reply.enabled", systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if model.telegramReplyState == .automationPermissionRequired {
                Button("bridge.telegram.reply.action.open_automation") {
                    model.openAutomationSettings()
                }
            }
        }
    }

    private var telegramDetail: LocalizedStringKey {
        switch model.telegramState {
        case .unconfigured: return "bridge.telegram.unconfigured"
        case .saved: return "bridge.telegram.saved"
        case .testing: return "bridge.telegram.testing"
        case .ready: return "bridge.telegram.ready"
        case .baselineRequired: return "bridge.telegram.baseline_required"
        case .forwarding: return "bridge.telegram.forwarding"
        case .forwarded: return "bridge.telegram.forwarded"
        case .invalidConfiguration: return "bridge.telegram.invalid"
        case .failed: return "bridge.telegram.failed"
        }
    }

    private var telegramReplyDetail: LocalizedStringKey {
        switch model.telegramReplyState {
        case .disabled: return "bridge.telegram.reply.disabled"
        case .establishing: return "bridge.telegram.reply.establishing"
        case .ready: return "bridge.telegram.reply.ready"
        case .checking: return "bridge.telegram.reply.checking"
        case .sent: return "bridge.telegram.reply.sent"
        case .noReplies: return "bridge.telegram.reply.none"
        case .privateChatRequired: return "bridge.telegram.reply.private_chat"
        case .automationPermissionRequired: return "bridge.telegram.reply.automation_permission"
        case .recipientUnavailable: return "bridge.telegram.reply.recipient_unavailable"
        case .failed: return "bridge.telegram.reply.failed"
        }
    }

    private var resetDialogTitle: LocalizedStringKey {
        switch resetTarget {
        case .validation: return "bridge.reset.validation.title"
        case .preview: return "bridge.reset.preview.title"
        case .telegram: return "bridge.reset.telegram.title"
        case .none: return "bridge.reset.preview.title"
        }
    }

    private var statusColor: Color {
        switch model.state {
        case .available: return .green
        case .permissionRequired, .unsupported, .failed: return .orange
        case .idle, .checking, .unavailable: return .secondary
        }
    }
}
