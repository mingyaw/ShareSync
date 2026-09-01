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
                errorCode: firstNonEmpty(record.lastErrorCode) ?? "SS-MEDIA-999"
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

    private func firstNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
