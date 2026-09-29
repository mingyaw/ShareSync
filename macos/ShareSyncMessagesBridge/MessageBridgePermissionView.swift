import AppKit
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

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else {
            return
        }
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
                Label("bridge.privacy.no_network", systemImage: "checkmark.circle")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            if case .available = model.state {
                Divider()
                validationSection
                Divider()
                previewSection
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

    private var resetDialogTitle: LocalizedStringKey {
        switch resetTarget {
        case .validation: return "bridge.reset.validation.title"
        case .preview, .none: return "bridge.reset.preview.title"
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
