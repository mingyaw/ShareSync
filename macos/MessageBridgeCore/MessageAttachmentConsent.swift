import Foundation

public struct MessageAttachmentConsent: Equatable, Sendable {
    public static let currentVersion = 1

    public let isEnabled: Bool
    public let acceptedVersion: Int?

    public init(isEnabled: Bool = false, acceptedVersion: Int? = nil) {
        self.isEnabled = isEnabled
        self.acceptedVersion = acceptedVersion
    }

    public static var currentAcceptance: MessageAttachmentConsent {
        MessageAttachmentConsent(isEnabled: true, acceptedVersion: currentVersion)
    }

    public var allowsUploads: Bool {
        isEnabled && acceptedVersion == Self.currentVersion
    }
}

public final class UserDefaultsMessageAttachmentConsentStore {
    private let defaults: UserDefaults
    private let enabledKey: String
    private let versionKey: String

    public init(
        defaults: UserDefaults,
        enabledKey: String,
        versionKey: String
    ) {
        self.defaults = defaults
        self.enabledKey = enabledKey
        self.versionKey = versionKey
    }

    public func load() -> MessageAttachmentConsent {
        MessageAttachmentConsent(
            isEnabled: defaults.bool(forKey: enabledKey),
            acceptedVersion: defaults.object(forKey: versionKey) as? Int
        )
    }

    public func save(_ consent: MessageAttachmentConsent) {
        defaults.set(consent.allowsUploads, forKey: enabledKey)
        if consent.allowsUploads, let acceptedVersion = consent.acceptedVersion {
            defaults.set(acceptedVersion, forKey: versionKey)
        } else {
            defaults.removeObject(forKey: versionKey)
        }
    }

    public func clear() {
        defaults.removeObject(forKey: enabledKey)
        defaults.removeObject(forKey: versionKey)
    }
}
