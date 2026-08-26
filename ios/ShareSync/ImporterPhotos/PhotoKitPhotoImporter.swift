import Foundation
import Photos

enum PhotoKitPhotoImporterError: Error {
    case photoPermissionDenied
    case unsupportedMediaType
    case missingPlaceholder
    case albumCreationFailed
}

final class PhotoKitPhotoImporter: PhotoImporter, PhotoLibraryPermissionChecking, PhotoAssetPresenceChecking {
    private let albumTitle: String
    private let library: PHPhotoLibrary

    init(albumTitle: String = "ShareSync Backup", library: PHPhotoLibrary = .shared()) {
        self.albumTitle = albumTitle
        self.library = library
    }

    func importBatch(_ requests: [PhotoImportRequest]) async -> [PhotoImportResult] {
        await withTaskGroup(of: PhotoImportResult.self) { group in
            for request in requests {
                group.addTask {
                    await self.importOne(request)
                }
            }

            var results: [PhotoImportResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    func assetExists(localIdentifier: String) async throws -> Bool {
        try await ensurePhotoPermission()
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return result.firstObject != nil
    }

    func photoLibraryPermissionStatus() -> PhotoLibraryPermissionStatus {
        Self.permissionStatus(from: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestPhotoLibraryPermission() async -> PhotoLibraryPermissionStatus {
        let current = photoLibraryPermissionStatus()
        if current != .notDetermined {
            return current
        }

        return Self.permissionStatus(from: await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    private func importOne(_ request: PhotoImportRequest) async -> PhotoImportResult {
        do {
            try await ensurePhotoPermission()
            let album = try await ensureAlbum()
            let localIdentifier = try await add(request: request, to: album)
            return PhotoImportResult(
                sourceAssetId: request.sourceAssetId,
                localIdentifier: localIdentifier,
                status: .synced,
                errorCode: nil
            )
        } catch {
            return PhotoImportResult(
                sourceAssetId: request.sourceAssetId,
                localIdentifier: nil,
                status: .failed,
                errorCode: errorCode(for: error)
            )
        }
    }

    private func ensurePhotoPermission() async throws {
        let current = photoLibraryPermissionStatus()
        if current.allowsImport {
            return
        }

        let requested = await requestPhotoLibraryPermission()
        guard requested.allowsImport else {
            throw PhotoKitPhotoImporterError.photoPermissionDenied
        }
    }

    private static func permissionStatus(from status: PHAuthorizationStatus) -> PhotoLibraryPermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }

    private func ensureAlbum() async throws -> PHAssetCollection {
        if let existing = fetchAlbum() {
            return existing
        }

        let placeholderIdentifier = try await performChanges {
            var localIdentifier: String?
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumTitle)
            localIdentifier = request.placeholderForCreatedAssetCollection.localIdentifier
            return localIdentifier
        }

        guard let placeholderIdentifier else {
            throw PhotoKitPhotoImporterError.albumCreationFailed
        }

        let result = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [placeholderIdentifier],
            options: nil
        )
        guard let collection = result.firstObject else {
            throw PhotoKitPhotoImporterError.albumCreationFailed
        }
        return collection
    }

    private func add(request: PhotoImportRequest, to album: PHAssetCollection) async throws -> String {
        try await performChanges {
            let placeholder: PHObjectPlaceholder?

            switch request.mediaType {
            case .photo:
                placeholder = PHAssetChangeRequest
                    .creationRequestForAssetFromImage(atFileURL: request.localFileURL)?
                    .placeholderForCreatedAsset
            case .video:
                placeholder = PHAssetChangeRequest
                    .creationRequestForAssetFromVideo(atFileURL: request.localFileURL)?
                    .placeholderForCreatedAsset
            }

            guard let placeholder else {
                throw PhotoKitPhotoImporterError.missingPlaceholder
            }

            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else {
                throw PhotoKitPhotoImporterError.albumCreationFailed
            }
            albumChangeRequest.addAssets([placeholder] as NSArray)
            return placeholder.localIdentifier
        }
    }

    private func fetchAlbum() -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumTitle)
        let result = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: options
        )
        return result.firstObject
    }

    private func performChanges<T>(_ changes: @escaping () throws -> T) async throws -> T {
        var value: T?
        var thrownError: Error?

        let result: T = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            library.performChanges {
                do {
                    value = try changes()
                } catch {
                    thrownError = error
                }
            } completionHandler: { success, error in
                if let thrownError {
                    continuation.resume(throwing: thrownError)
                } else if let error {
                    continuation.resume(throwing: error)
                } else if success, let value {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(throwing: PhotoKitPhotoImporterError.albumCreationFailed)
                }
            }
        }
        return result
    }

    private func errorCode(for error: Error) -> String {
        if let importerError = error as? PhotoKitPhotoImporterError {
            switch importerError {
            case .photoPermissionDenied:
                return "SS-PERM-001"
            case .unsupportedMediaType:
                return "SS-MEDIA-001"
            case .missingPlaceholder, .albumCreationFailed:
                return "SS-MEDIA-999"
            }
        }

        return "SS-MEDIA-999"
    }
}
