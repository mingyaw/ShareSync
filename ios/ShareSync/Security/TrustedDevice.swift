import Foundation

struct TrustedDevice: Codable, Equatable, Identifiable {
    var id: String { deviceId }

    let deviceId: String
    let deviceName: String
    let platform: String
    let publicKey: String
    let pairedAt: Date
    let lastSeenAt: Date?
    let trustStatus: TrustStatus
}

enum TrustStatus: String, Codable {
    case trusted
    case revoked
}

