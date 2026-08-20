import Foundation

struct MediaDownloadRecord: Codable, Equatable, Identifiable {
    var id: String { sourceAssetId }

    let sourceAssetId: String
    let sourceHash: String?
    var status: MediaDownloadStatus
    var localFileURL: URL?
    var downloadedBytes: Int64
    var totalBytes: Int64
    var attemptCount: Int
    var lastErrorCode: String?
    var updatedAt: Date
}

enum MediaDownloadStatus: String, Codable {
    case queued
    case downloading
    case downloaded
    case imported
    case skipped
    case failed
}

protocol MediaDownloadStateStore {
    func record(for sourceAssetId: String) -> MediaDownloadRecord?
    func upsertQueued(asset: MediaAsset, now: Date)
    func markDownloading(sourceAssetId: String, downloadedBytes: Int64, now: Date)
    func markDownloaded(sourceAssetId: String, localFileURL: URL, downloadedBytes: Int64, now: Date)
    func markImported(sourceAssetId: String, now: Date)
    func markSkipped(sourceAssetId: String, now: Date)
    func markFailed(sourceAssetId: String, errorCode: String, now: Date)
    func pendingRecords() -> [MediaDownloadRecord]
}

final class InMemoryMediaDownloadStateStore: MediaDownloadStateStore {
    private var records: [String: MediaDownloadRecord] = [:]

    func record(for sourceAssetId: String) -> MediaDownloadRecord? {
        records[sourceAssetId]
    }

    func upsertQueued(asset: MediaAsset, now: Date = Date()) {
        if let existing = records[asset.assetId],
           existing.status == .downloaded || existing.status == .imported || existing.status == .skipped {
            return
        }

        records[asset.assetId] = MediaDownloadRecord(
            sourceAssetId: asset.assetId,
            sourceHash: asset.sha256,
            status: .queued,
            localFileURL: nil,
            downloadedBytes: 0,
            totalBytes: asset.size,
            attemptCount: records[asset.assetId]?.attemptCount ?? 0,
            lastErrorCode: nil,
            updatedAt: now
        )
    }

    func markDownloading(sourceAssetId: String, downloadedBytes: Int64, now: Date = Date()) {
        mutate(sourceAssetId: sourceAssetId, now: now) { record in
            record.status = .downloading
            record.downloadedBytes = max(0, downloadedBytes)
        }
    }

    func markDownloaded(sourceAssetId: String, localFileURL: URL, downloadedBytes: Int64, now: Date = Date()) {
        mutate(sourceAssetId: sourceAssetId, now: now) { record in
            record.status = .downloaded
            record.localFileURL = localFileURL
            record.downloadedBytes = max(0, downloadedBytes)
            record.lastErrorCode = nil
        }
    }

    func markImported(sourceAssetId: String, now: Date = Date()) {
        mutate(sourceAssetId: sourceAssetId, now: now) { record in
            record.status = .imported
        }
    }

    func markSkipped(sourceAssetId: String, now: Date = Date()) {
        mutate(sourceAssetId: sourceAssetId, now: now) { record in
            record.status = .skipped
        }
    }

    func markFailed(sourceAssetId: String, errorCode: String, now: Date = Date()) {
        mutate(sourceAssetId: sourceAssetId, now: now) { record in
            record.status = .failed
            record.attemptCount += 1
            record.lastErrorCode = errorCode
        }
    }

    func pendingRecords() -> [MediaDownloadRecord] {
        records.values
            .filter { record in
                record.status == .queued || record.status == .downloading || record.status == .failed
            }
            .sorted { lhs, rhs in
                lhs.updatedAt < rhs.updatedAt
            }
    }

    private func mutate(
        sourceAssetId: String,
        now: Date,
        update: (inout MediaDownloadRecord) -> Void
    ) {
        guard var record = records[sourceAssetId] else {
            return
        }
        update(&record)
        record.updatedAt = now
        records[sourceAssetId] = record
    }
}

