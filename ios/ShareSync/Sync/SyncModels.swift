import Foundation

struct PairingPayload: Codable, Equatable {
    let version: Int
    let type: String
    let deviceId: String
    let deviceName: String
    let platform: String
    let publicKey: String
    let ip: String
    let port: Int
    let pairingToken: String
    let expiresAt: Date
}

struct SyncManifest: Codable, Equatable {
    let version: Int
    let sourceDeviceId: String
    let generatedAt: Date
    let cursor: String
    let media: [MediaAsset]
    let contacts: [ContactItem]
    let files: [FileItem]
}

struct MediaAsset: Codable, Equatable, Identifiable {
    var id: String { assetId }

    let assetId: String
    let sourceDeviceId: String
    let mediaType: MediaType
    let fileName: String
    let mimeType: String
    let size: Int64
    let sha256: String?
    let createdAt: Date?
    let modifiedAt: Date?
    let takenAt: Date?
    let width: Int?
    let height: Int?
    let durationMs: Int64?
    let relativePath: String?
}

enum MediaType: String, Codable {
    case photo
    case video
}

struct ContactItem: Codable, Equatable, Identifiable {
    var id: String { contactId }

    let contactId: String
    let sourceDeviceId: String
    let displayName: String
    let phones: [String]
    let emails: [String]
}

struct FileItem: Codable, Equatable, Identifiable {
    var id: String { fileId }

    let fileId: String
    let sourceDeviceId: String
    let fileName: String
    let relativePath: String
    let size: Int64
    let mimeType: String?
    let sha256: String?
}

struct SyncResult: Codable, Equatable {
    let syncBatchId: String
    let targetDeviceId: String
    let results: [SyncItemResult]
}

struct SyncItemResult: Codable, Equatable {
    let itemType: SyncItemType
    let sourceItemId: String
    let targetItemId: String?
    let status: SyncItemStatus
    let errorCode: String?
}

enum SyncItemType: String, Codable {
    case media
    case contact
    case file
}

enum SyncItemStatus: String, Codable {
    case synced
    case skipped
    case failed
    case conflicted
}

