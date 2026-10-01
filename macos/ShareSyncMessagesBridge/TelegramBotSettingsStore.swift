import Foundation

struct TelegramBotSettings: Equatable {
    var chatID: String
    var allowedSenderIdentifiers: [String]
    var automaticForwardingEnabled: Bool
    var repliesEnabled: Bool
}

final class TelegramBotSettingsStore {
    private enum Key {
        static let chatID = "messages.telegram.chat-id"
        static let allowedSender = "messages.telegram.allowed-sender"
        static let allowedSenders = "messages.telegram.allowed-senders"
        static let automaticForwarding = "messages.telegram.automatic-forwarding"
        static let repliesEnabled = "messages.telegram.replies-enabled"
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
        return TelegramBotSettings(
            chatID: defaults.string(forKey: Key.chatID) ?? "",
            allowedSenderIdentifiers: allowedSenders,
            automaticForwardingEnabled: defaults.bool(forKey: Key.automaticForwarding),
            repliesEnabled: defaults.bool(forKey: Key.repliesEnabled)
        )
    }

    func saveSettings(_ settings: TelegramBotSettings) {
        defaults.set(settings.chatID, forKey: Key.chatID)
        let senders = normalizedSenders(settings.allowedSenderIdentifiers)
        defaults.set(senders, forKey: Key.allowedSenders)
        defaults.set(senders.first ?? "", forKey: Key.allowedSender)
        defaults.set(settings.automaticForwardingEnabled, forKey: Key.automaticForwarding)
        defaults.set(settings.repliesEnabled, forKey: Key.repliesEnabled)
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
}
