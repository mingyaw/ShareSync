import Foundation

struct M0PhotoTransferPlanner {
    func nextTransferCandidates(
        in manifest: SyncManifest,
        stateStore: MediaDownloadStateStore,
        limit: Int
    ) -> [MediaAsset] {
        guard limit > 0 else {
            return []
        }

        return Array(photoAssets(in: manifest).lazy.filter { asset in
            guard let record = stateStore.record(for: asset.assetId) else {
                return true
            }

            return record.status == .queued
                || record.status == .downloading
                || record.status == .downloaded
                || record.status == .missing
                || record.status == .failed
        }.prefix(limit))
    }

    func photoAssets(in manifest: SyncManifest) -> [MediaAsset] {
        manifest.media.filter { $0.mediaType == .photo }
    }
}
