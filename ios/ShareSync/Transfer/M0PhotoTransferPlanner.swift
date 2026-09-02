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

        let candidates = photoAssets(in: manifest).enumerated().compactMap { index, asset -> TransferCandidate? in
            guard let record = stateStore.record(for: asset.assetId) else {
                return TransferCandidate(asset: asset, manifestIndex: index, priority: .new)
            }

            guard let priority = TransferPriority(status: record.status) else {
                return nil
            }

            return TransferCandidate(asset: asset, manifestIndex: index, priority: priority)
        }

        return Array(
            candidates
                .sorted()
                .lazy
                .map(\.asset)
                .prefix(limit)
        )
    }

    func photoAssets(in manifest: SyncManifest) -> [MediaAsset] {
        manifest.media.filter { $0.mediaType == .photo }
    }
}

private struct TransferCandidate: Comparable {
    let asset: MediaAsset
    let manifestIndex: Int
    let priority: TransferPriority

    static func < (lhs: TransferCandidate, rhs: TransferCandidate) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }

        return lhs.manifestIndex < rhs.manifestIndex
    }
}

private enum TransferPriority: Int, Comparable {
    case downloaded = 0
    case retryable = 1
    case new = 2

    init?(status: MediaDownloadStatus) {
        switch status {
        case .downloaded:
            self = .downloaded
        case .queued, .downloading, .missing, .failed:
            self = .retryable
        case .imported, .skipped:
            return nil
        }
    }

    static func < (lhs: TransferPriority, rhs: TransferPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
