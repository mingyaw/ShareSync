import Foundation

struct PhotoImportRequest: Equatable {
    let sourceAssetId: String
    let sourceHash: String?
    let sourceSize: Int64
    let localFileURL: URL
    let mediaType: MediaType
}

enum PhotoImportRequestValidationError: Error, Equatable {
    case fileSizeMismatch(expected: Int64, actual: Int64)
}

struct PhotoImportRequestValidator {
    private let fileSize: (URL) throws -> Int64

    init(fileSize: @escaping (URL) throws -> Int64 = Self.fileSize) {
        self.fileSize = fileSize
    }

    func validate(_ request: PhotoImportRequest) throws {
        let actualSize = try fileSize(request.localFileURL)
        guard actualSize == request.sourceSize else {
            throw PhotoImportRequestValidationError.fileSizeMismatch(
                expected: request.sourceSize,
                actual: actualSize
            )
        }
    }

    private static func fileSize(for url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }
}

struct PhotoImportResult: Equatable {
    let sourceAssetId: String
    let localIdentifier: String?
    let status: SyncItemStatus
    let errorCode: String?
}

enum PhotoLibraryPermissionStatus: String, Equatable {
    case authorized
    case limited
    case denied
    case restricted
    case notDetermined
    case unknown

    var allowsImport: Bool {
        self == .authorized || self == .limited
    }
}

protocol PhotoImporter {
    func importBatch(_ requests: [PhotoImportRequest]) async -> [PhotoImportResult]
}

protocol PhotoLibraryPermissionChecking {
    func photoLibraryPermissionStatus() -> PhotoLibraryPermissionStatus
    func requestPhotoLibraryPermission() async -> PhotoLibraryPermissionStatus
}

protocol PhotoAssetPresenceChecking {
    func assetExists(localIdentifier: String) async throws -> Bool
}

final class PhotoImporterStub: PhotoImporter {
    func importBatch(_ requests: [PhotoImportRequest]) async -> [PhotoImportResult] {
        requests.map {
            PhotoImportResult(
                sourceAssetId: $0.sourceAssetId,
                localIdentifier: nil,
                status: .failed,
                errorCode: "SS-MEDIA-999"
            )
        }
    }
}

final class PhotoAssetPresenceCheckerStub: PhotoAssetPresenceChecking {
    func assetExists(localIdentifier: String) async throws -> Bool {
        false
    }
}

final class PhotoLibraryPermissionCheckerStub: PhotoLibraryPermissionChecking {
    private let status: PhotoLibraryPermissionStatus

    init(status: PhotoLibraryPermissionStatus) {
        self.status = status
    }

    func photoLibraryPermissionStatus() -> PhotoLibraryPermissionStatus {
        status
    }

    func requestPhotoLibraryPermission() async -> PhotoLibraryPermissionStatus {
        status
    }
}
