import Foundation

struct TelegramBotSettings: Equatable {
    var chatID: String
    var allowedSenderIdentifier: String
}

final class TelegramBotSettingsStore {
    private enum Key {
        static let chatID = "messages.telegram.chat-id"
        static let allowedSender = "messages.telegram.allowed-sender"
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
        TelegramBotSettings(
            chatID: defaults.string(forKey: Key.chatID) ?? "",
            allowedSenderIdentifier: defaults.string(forKey: Key.allowedSender) ?? ""
        )
    }

    func saveSettings(_ settings: TelegramBotSettings) {
        defaults.set(settings.chatID, forKey: Key.chatID)
        defaults.set(settings.allowedSenderIdentifier, forKey: Key.allowedSender)
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
        try vault.removeCredential(for: Key.credentialID)
    }
}
