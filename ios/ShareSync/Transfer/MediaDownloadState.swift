import Foundation

struct MediaDownloadRecord: Codable, Equatable, Identifiable {
    var id: String { sourceAssetId }

    let sourceAssetId: String
    let sourceHash: String?
    var status: MediaDownloadStatus
    var localFileURL: URL?
    var photoLocalIdentifier: String?
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
    case missing
    case skipped
    case failed
}

protocol MediaDownloadStateStore {
    func record(for sourceAssetId: String) -> MediaDownloadRecord?
    func upsertQueued(asset: MediaAsset, now: Date)
    func markDownloading(sourceAssetId: String, downloadedBytes: Int64, now: Date)
    func markDownloaded(sourceAssetId: String, localFileURL: URL, downloadedBytes: Int64, now: Date)
    func markImported(sourceAssetId: String, photoLocalIdentifier: String?, now: Date)
    func markMissing(sourceAssetId: String, now: Date)
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
            photoLocalIdentifier: nil,
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

    func markImported(sourceAssetId: String, photoLocalIdentifier: String?, now: Date = Date()) {
        mutate(sourceAssetId: sourceAssetId, now: now) { record in
            record.status = .imported
            record.photoLocalIdentifier = photoLocalIdentifier
        }
    }

    func markMissing(sourceAssetId: String, now: Date = Date()) {
        mutate(sourceAssetId: sourceAssetId, now: now) { record in
            record.status = .missing
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

final class FileMediaDownloadStateStore: MediaDownloadStateStore {
    private var records: [String: MediaDownloadRecord]
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultStoreURL(fileManager: fileManager)
        self.records = Self.loadRecords(fileManager: fileManager, fileURL: self.fileURL)
    }

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
            photoLocalIdentifier: nil,
            downloadedBytes: 0,
            totalBytes: asset.size,
            attemptCount: records[asset.assetId]?.attemptCount ?? 0,
            lastErrorCode: nil,
            updatedAt: now
        )
        persist()
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

    func markImported(sourceAssetId: String, photoLocalIdentifier: String?, now: Date = Date()) {
        mutate(sourceAssetId: sourceAssetId, now: now) { record in
            record.status = .imported
            record.photoLocalIdentifier = photoLocalIdentifier
        }
    }

    func markMissing(sourceAssetId: String, now: Date = Date()) {
        mutate(sourceAssetId: sourceAssetId, now: now) { record in
            record.status = .missing
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
        persist()
    }

    private func persist() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder.mediaDownloadStateEncoder.encode(Array(records.values))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to persist media download state: \(error)")
        }
    }

    private static func loadRecords(fileManager: FileManager, fileURL: URL) -> [String: MediaDownloadRecord] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder.mediaDownloadStateDecoder.decode([MediaDownloadRecord].self, from: data) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: records.map { ($0.sourceAssetId, $0) })
    }

    private static func defaultStoreURL(fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseDirectory
            .appendingPathComponent("ShareSync", isDirectory: true)
            .appendingPathComponent("media-download-state.json", isDirectory: false)
    }
}

private extension JSONEncoder {
    static var mediaDownloadStateEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var mediaDownloadStateDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
