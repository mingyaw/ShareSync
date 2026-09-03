import Foundation

enum SyncEventPhase: String, Codable, Equatable {
    case fetchManifest = "fetch_manifest"
    case download
    case importPhotos = "import_photos"
    case resultPost = "result_post"
}

enum SyncEventStatus: String, Codable, Equatable {
    case success
    case failed
    case cancelled
}

struct SyncEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let phase: SyncEventPhase
    let status: SyncEventStatus
    let recordedAt: Date
    let sourceDeviceId: String?
    let targetDeviceId: String
    let syncBatchId: String?
    let photoCount: Int
    let syncedCount: Int
    let skippedCount: Int
    let failedCount: Int
    let errorCode: String?

    var successfulCount: Int {
        syncedCount + skippedCount
    }

    static func fromResultPost(
        result: SyncResult,
        status: SyncEventStatus,
        recordedAt: Date,
        errorCode: String? = nil
    ) -> SyncEvent {
        SyncEvent(
            id: UUID(),
            phase: .resultPost,
            status: status,
            recordedAt: recordedAt,
            sourceDeviceId: nil,
            targetDeviceId: result.targetDeviceId,
            syncBatchId: result.syncBatchId,
            photoCount: result.results.filter { $0.itemType == .media }.count,
            syncedCount: result.results.filter { $0.itemType == .media && $0.status == .synced }.count,
            skippedCount: result.results.filter { $0.itemType == .media && $0.status == .skipped }.count,
            failedCount: result.results.filter {
                $0.itemType == .media && ($0.status == .failed || $0.status == .conflicted)
            }.count,
            errorCode: errorCode
        )
    }
}

protocol SyncEventStore {
    func append(_ event: SyncEvent) throws
    func latest() throws -> SyncEvent?
    func latestSuccessfulSync() throws -> SyncEvent?
    func all() throws -> [SyncEvent]
    func clear() throws
}

final class InMemorySyncEventStore: SyncEventStore {
    private var events: [SyncEvent] = []

    func append(_ event: SyncEvent) throws {
        events.append(event)
    }

    func latest() throws -> SyncEvent? {
        events.last
    }

    func latestSuccessfulSync() throws -> SyncEvent? {
        events.last { event in
            event.status == .success && (event.phase == .importPhotos || event.phase == .resultPost)
        }
    }

    func all() throws -> [SyncEvent] {
        events
    }

    func clear() throws {
        events.removeAll()
    }
}

final class FileSyncEventStore: SyncEventStore {
    private static let maxEvents = 50

    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultStoreURL(fileManager: fileManager)
    }

    func append(_ event: SyncEvent) throws {
        let updatedEvents = try (all() + [event]).suffix(Self.maxEvents)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.syncEventEncoder.encode(Array(updatedEvents))
        try data.write(to: fileURL, options: [.atomic])
    }

    func latest() throws -> SyncEvent? {
        try all().last
    }

    func latestSuccessfulSync() throws -> SyncEvent? {
        try all().last { event in
            event.status == .success && (event.phase == .importPhotos || event.phase == .resultPost)
        }
    }

    func all() throws -> [SyncEvent] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.syncEventDecoder.decode([SyncEvent].self, from: data)
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }

    private static func defaultStoreURL(fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseDirectory
            .appendingPathComponent("ShareSync", isDirectory: true)
            .appendingPathComponent("sync-events.json", isDirectory: false)
    }
}

private extension JSONEncoder {
    static var syncEventEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var syncEventDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
