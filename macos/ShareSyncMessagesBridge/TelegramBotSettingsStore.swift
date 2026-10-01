import Foundation

struct TelegramBotSettings: Equatable {
    var chatID: String
    var allowedSenderIdentifiers: [String]
    var automaticForwardingEnabled: Bool
    var repliesEnabled: Bool
    var forwardingPaused: Bool
    var scheduleEnabled: Bool
    var scheduleStartMinute: Int
    var scheduleEndMinute: Int
}

final class TelegramBotSettingsStore {
    private enum Key {
        static let chatID = "messages.telegram.chat-id"
        static let allowedSender = "messages.telegram.allowed-sender"
        static let allowedSenders = "messages.telegram.allowed-senders"
        static let automaticForwarding = "messages.telegram.automatic-forwarding"
        static let repliesEnabled = "messages.telegram.replies-enabled"
        static let forwardingPaused = "messages.telegram.forwarding-paused"
        static let scheduleEnabled = "messages.telegram.schedule-enabled"
        static let scheduleStartMinute = "messages.telegram.schedule-start-minute"
        static let scheduleEndMinute = "messages.telegram.schedule-end-minute"
        static let credentialID = "telegram-bot-token"
    }

    private let defaults: UserDefaults
    private let vault: KeychainMessageConnectorCredentialVault

    init(
        defaults: UserDefaults = .standard,
        vault: KeychainMessageConnectorCredentialVault = KeychainMessageConnectorCredentialVault(
            service: "com.sharesync.mac.telegram"
        )
    ) {
        self.defaults = defaults
        self.vault = vault
    }

    func loadSettings() -> TelegramBotSettings {
        let storedSenders = defaults.stringArray(forKey: Key.allowedSenders)
        let legacySender = defaults.string(forKey: Key.allowedSender) ?? ""
        let allowedSenders = normalizedSenders(
            storedSenders ?? (legacySender.isEmpty ? [] : [legacySender])
        )
        if storedSenders == nil, !allowedSenders.isEmpty {
            defaults.set(allowedSenders, forKey: Key.allowedSenders)
        }
        let startMinute = defaults.object(forKey: Key.scheduleStartMinute) == nil
            ? 8 * 60
            : defaults.integer(forKey: Key.scheduleStartMinute)
        let endMinute = defaults.object(forKey: Key.scheduleEndMinute) == nil
            ? 22 * 60
            : defaults.integer(forKey: Key.scheduleEndMinute)
        return TelegramBotSettings(
            chatID: defaults.string(forKey: Key.chatID) ?? "",
            allowedSenderIdentifiers: allowedSenders,
            automaticForwardingEnabled: defaults.bool(forKey: Key.automaticForwarding),
            repliesEnabled: defaults.bool(forKey: Key.repliesEnabled),
            forwardingPaused: defaults.bool(forKey: Key.forwardingPaused),
            scheduleEnabled: defaults.bool(forKey: Key.scheduleEnabled),
            scheduleStartMinute: clampedMinute(startMinute),
            scheduleEndMinute: clampedMinute(endMinute)
        )
    }

    func saveSettings(_ settings: TelegramBotSettings) {
        defaults.set(settings.chatID, forKey: Key.chatID)
        let senders = normalizedSenders(settings.allowedSenderIdentifiers)
        defaults.set(senders, forKey: Key.allowedSenders)
        defaults.set(senders.first ?? "", forKey: Key.allowedSender)
        defaults.set(settings.automaticForwardingEnabled, forKey: Key.automaticForwarding)
        defaults.set(settings.repliesEnabled, forKey: Key.repliesEnabled)
        saveRuntimeControls(settings)
    }

    func setAutomaticForwardingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.automaticForwarding)
    }

    func setRepliesEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.repliesEnabled)
    }

    func setAllowedSenderIdentifiers(_ identifiers: [String]) {
        let senders = normalizedSenders(identifiers)
        defaults.set(senders, forKey: Key.allowedSenders)
        defaults.set(senders.first ?? "", forKey: Key.allowedSender)
    }

    func saveRuntimeControls(_ settings: TelegramBotSettings) {
        defaults.set(settings.forwardingPaused, forKey: Key.forwardingPaused)
        defaults.set(settings.scheduleEnabled, forKey: Key.scheduleEnabled)
        defaults.set(clampedMinute(settings.scheduleStartMinute), forKey: Key.scheduleStartMinute)
        defaults.set(clampedMinute(settings.scheduleEndMinute), forKey: Key.scheduleEndMinute)
    }

    func loadToken() throws -> String? {
        guard let data = try vault.credential(for: Key.credentialID) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveToken(_ token: String) throws {
        try vault.setCredential(Data(token.utf8), for: Key.credentialID)
    }

    func clear() throws {
        defaults.removeObject(forKey: Key.chatID)
        defaults.removeObject(forKey: Key.allowedSender)
        defaults.removeObject(forKey: Key.allowedSenders)
        defaults.removeObject(forKey: Key.automaticForwarding)
        defaults.removeObject(forKey: Key.repliesEnabled)
        defaults.removeObject(forKey: Key.forwardingPaused)
        defaults.removeObject(forKey: Key.scheduleEnabled)
        defaults.removeObject(forKey: Key.scheduleStartMinute)
        defaults.removeObject(forKey: Key.scheduleEndMinute)
        try vault.removeCredential(for: Key.credentialID)
    }

    private func normalizedSenders(_ identifiers: [String]) -> [String] {
        var seen: Set<String> = []
        return identifiers.compactMap { identifier in
            let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    private func clampedMinute(_ minute: Int) -> Int {
        min(max(minute, 0), 1_439)
    }
}
