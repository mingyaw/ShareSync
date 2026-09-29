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

    enum ValidationState: Equatable {
        case inactive
        case establishing
        case ready
        case checking
        case empty
        case result(MessageValidationSummary)
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
        case .permissionRequired:
            state = .permissionRequired
        case .unavailable:
            state = .unavailable
        case .unsupportedSchema(_, let missing):
            state = .unsupported(missing)
        case .failed(let code):
            state = .failed(code)
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
        let databaseURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Messages/chat.db")
        return ControlledMessageValidationSession(
            reader: MessageEventReader(databaseURL: databaseURL),
            cursorStore: cursorStore()
        )
    }

    private func cursorStore() -> FileMessageCursorStore {
        let applicationSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = applicationSupport ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return FileMessageCursorStore(
            fileURL: root
                .appendingPathComponent("ShareSync/MessagesBridge", isDirectory: true)
                .appendingPathComponent("validation-cursor.json")
        )
    }
}

struct MessageBridgePermissionView: View {
    @EnvironmentObject private var model: MessageBridgePermissionViewModel

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

    private var statusColor: Color {
        switch model.state {
        case .available: return .green
        case .permissionRequired, .unsupported, .failed: return .orange
        case .idle, .checking, .unavailable: return .secondary
        }
    }
}
