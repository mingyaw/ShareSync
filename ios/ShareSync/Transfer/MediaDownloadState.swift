import Foundation

struct MediaDownloadRecord: Codable, Equatable, Identifiable {
    var id: String { sourceAssetId }

    var sourceDeviceId: String?
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

struct MediaImportMapping: Equatable {
    let sourceDeviceId: String?
    let sourceAssetId: String
    let sourceHash: String?
    let photoLocalIdentifier: String
    let importedAt: Date
}

protocol MediaDownloadStateStore {
    func record(for sourceAssetId: String) -> MediaDownloadRecord?
    func allRecords() -> [MediaDownloadRecord]
    func upsertQueued(asset: MediaAsset, now: Date)
    func markDownloading(sourceAssetId: String, downloadedBytes: Int64, now: Date)
    func markDownloaded(sourceAssetId: String, localFileURL: URL, downloadedBytes: Int64, now: Date)
    func markImported(sourceAssetId: String, photoLocalIdentifier: String?, now: Date)
    func markMissing(sourceAssetId: String, now: Date)
    func markSkipped(sourceAssetId: String, now: Date)
    func markFailed(sourceAssetId: String, errorCode: String, now: Date)
    func pendingRecords() -> [MediaDownloadRecord]
    func resumablePartialRecords() -> [MediaDownloadRecord]
    func importedMappings() -> [MediaImportMapping]
    func clear()
}

final class InMemoryMediaDownloadStateStore: MediaDownloadStateStore {
    private var records: [String: MediaDownloadRecord] = [:]

    func record(for sourceAssetId: String) -> MediaDownloadRecord? {
        records[sourceAssetId]
    }

    func allRecords() -> [MediaDownloadRecord] {
        records.values.sorted { lhs, rhs in
            lhs.updatedAt < rhs.updatedAt
        }
    }

    func upsertQueued(asset: MediaAsset, now: Date = Date()) {
        if let existing = records[asset.assetId],
           existing.status == .downloaded || existing.status == .imported || existing.status == .skipped {
            return
        }

        let existing = records[asset.assetId]
        records[asset.assetId] = MediaDownloadRecord(
            sourceDeviceId: asset.sourceDeviceId,
            sourceAssetId: asset.assetId,
            sourceHash: asset.sha256,
            status: .queued,
            localFileURL: existing?.localFileURL,
            photoLocalIdentifier: nil,
            downloadedBytes: existing?.downloadedBytes ?? 0,
            totalBytes: asset.size,
            attemptCount: existing?.attemptCount ?? 0,
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
            record.localFileURL = nil
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

    func resumablePartialRecords() -> [MediaDownloadRecord] {
        records.values
            .filter(\.isResumablePartial)
            .sorted { lhs, rhs in
                lhs.updatedAt < rhs.updatedAt
            }
    }

    func importedMappings() -> [MediaImportMapping] {
        records.values
            .compactMap(MediaImportMapping.init(record:))
            .sorted { lhs, rhs in
                lhs.importedAt < rhs.importedAt
            }
    }

    func clear() {
        records.removeAll()
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
    private let fileExists: (URL) -> Bool

    init(
        fileManager: FileManager = .default,
        fileURL: URL? = nil,
        fileExists: ((URL) -> Bool)? = nil
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultStoreURL(fileManager: fileManager)
        self.fileExists = fileExists ?? { fileManager.fileExists(atPath: $0.path) }
        self.records = Self.loadRecords(fileManager: fileManager, fileURL: self.fileURL)
    }

    func record(for sourceAssetId: String) -> MediaDownloadRecord? {
        records[sourceAssetId]
    }

    func allRecords() -> [MediaDownloadRecord] {
        records.values.sorted { lhs, rhs in
            lhs.updatedAt < rhs.updatedAt
        }
    }

    func upsertQueued(asset: MediaAsset, now: Date = Date()) {
        if let existing = records[asset.assetId],
           existing.status == .downloaded || existing.status == .imported || existing.status == .skipped {
            return
        }

        let existing = records[asset.assetId]
        records[asset.assetId] = MediaDownloadRecord(
            sourceDeviceId: asset.sourceDeviceId,
            sourceAssetId: asset.assetId,
            sourceHash: asset.sha256,
            status: .queued,
            localFileURL: existing?.localFileURL,
            photoLocalIdentifier: nil,
            downloadedBytes: existing?.downloadedBytes ?? 0,
            totalBytes: asset.size,
            attemptCount: existing?.attemptCount ?? 0,
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
            record.localFileURL = nil
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

    func resumablePartialRecords() -> [MediaDownloadRecord] {
        records.values
            .filter { record in
                record.isResumablePartial && record.localFileURL.map(fileExists) == true
            }
            .sorted { lhs, rhs in
                lhs.updatedAt < rhs.updatedAt
            }
    }

    func importedMappings() -> [MediaImportMapping] {
        records.values
            .compactMap(MediaImportMapping.init(record:))
            .sorted { lhs, rhs in
                lhs.importedAt < rhs.importedAt
            }
    }

    func clear() {
        records.removeAll()
        do {
            guard fileManager.fileExists(atPath: fileURL.path) else {
                return
            }

            try fileManager.removeItem(at: fileURL)
        } catch {
            assertionFailure("Failed to clear media download state: \(error)")
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

private extension MediaImportMapping {
    init?(record: MediaDownloadRecord) {
        guard record.status == .imported,
              let photoLocalIdentifier = record.photoLocalIdentifier,
              !photoLocalIdentifier.isEmpty else {
            return nil
        }

        self.init(
            sourceDeviceId: record.sourceDeviceId,
            sourceAssetId: record.sourceAssetId,
            sourceHash: record.sourceHash,
            photoLocalIdentifier: photoLocalIdentifier,
            importedAt: record.updatedAt
        )
    }
}

private extension MediaDownloadRecord {
    var isResumablePartial: Bool {
        guard localFileURL != nil,
              downloadedBytes > 0,
              downloadedBytes < totalBytes else {
            return false
        }

        return status == .queued || status == .downloading || status == .failed
    }
}
