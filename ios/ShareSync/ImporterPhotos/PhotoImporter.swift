import Foundation

struct PhotoImportRequest: Equatable {
    let sourceAssetId: String
    let sourceHash: String?
    let localFileURL: URL
    let mediaType: MediaType
}

struct PhotoImportResult: Equatable {
    let sourceAssetId: String
    let localIdentifier: String?
    let status: SyncItemStatus
    let errorCode: String?
}

protocol PhotoImporter {
    func importBatch(_ requests: [PhotoImportRequest]) async -> [PhotoImportResult]
}

final class PhotoImporterStub: PhotoImporter {
    func importBatch(_ requests: [PhotoImportRequest]) async -> [PhotoImportResult] {
        requests.map {
            PhotoImportResult(
                sourceAssetId: $0.sourceAssetId,
                localIdentifier: nil,
                status: .failed,
                errorCode: "SS-MEDIA-POC"
            )
        }
    }
}

