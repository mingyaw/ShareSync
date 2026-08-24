import Foundation

protocol SyncResultStore {
    func save(_ result: SyncResult) throws
    func latest() throws -> SyncResult?
}

final class FileSyncResultStore: SyncResultStore {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultStoreURL(fileManager: fileManager)
    }

    func save(_ result: SyncResult) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.syncResultEncoder.encode(result)
        try data.write(to: fileURL, options: [.atomic])
    }

    func latest() throws -> SyncResult? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.syncResultDecoder.decode(SyncResult.self, from: data)
    }

    private static func defaultStoreURL(fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseDirectory
            .appendingPathComponent("ShareSync", isDirectory: true)
            .appendingPathComponent("latest-sync-result.json", isDirectory: false)
    }
}

private extension JSONEncoder {
    static var syncResultEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var syncResultDecoder: JSONDecoder {
        JSONDecoder()
    }
}
