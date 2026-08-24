import Foundation

struct SyncResultBuilder {
    func buildMediaResult(
        syncBatchId: String,
        targetDeviceId: String,
        records: [MediaDownloadRecord]
    ) -> SyncResult {
        SyncResult(
            syncBatchId: syncBatchId,
            targetDeviceId: targetDeviceId,
            results: records.compactMap(makeItemResult(record:))
        )
    }

    private func makeItemResult(record: MediaDownloadRecord) -> SyncItemResult? {
        switch record.status {
        case .imported:
            return SyncItemResult(
                itemType: .media,
                sourceItemId: record.sourceAssetId,
                targetItemId: record.photoLocalIdentifier,
                status: .synced,
                errorCode: nil
            )
        case .skipped:
            return SyncItemResult(
                itemType: .media,
                sourceItemId: record.sourceAssetId,
                targetItemId: record.photoLocalIdentifier,
                status: .skipped,
                errorCode: nil
            )
        case .failed:
            return SyncItemResult(
                itemType: .media,
                sourceItemId: record.sourceAssetId,
                targetItemId: record.photoLocalIdentifier,
                status: .failed,
                errorCode: record.lastErrorCode
            )
        case .missing:
            return SyncItemResult(
                itemType: .media,
                sourceItemId: record.sourceAssetId,
                targetItemId: record.photoLocalIdentifier,
                status: .failed,
                errorCode: "SS-MEDIA-002"
            )
        case .queued, .downloading, .downloaded:
            return nil
        }
    }
}
