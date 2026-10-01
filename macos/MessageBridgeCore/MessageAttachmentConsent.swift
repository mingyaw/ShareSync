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
