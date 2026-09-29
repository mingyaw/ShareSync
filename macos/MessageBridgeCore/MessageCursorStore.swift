import Foundation

public protocol MessageCursorStore {
    func load() throws -> MessageCursor?
    func save(_ cursor: MessageCursor) throws
    func clear() throws
}

public final class FileMessageCursorStore: MessageCursorStore {
    private struct Envelope: Codable {
        let version: Int
        let cursor: MessageCursor
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> MessageCursor? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let envelope = try decoder.decode(Envelope.self, from: Data(contentsOf: fileURL))
        guard envelope.version == 1 else {
            throw MessageCursorStoreError.unsupportedVersion(envelope.version)
        }
        return envelope.cursor
    }

    public func save(_ cursor: MessageCursor) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(Envelope(version: 1, cursor: cursor))
        try data.write(to: fileURL, options: .atomic)
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }
}

public enum MessageCursorStoreError: Error, Equatable {
    case unsupportedVersion(Int)
}
