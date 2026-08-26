import Foundation

struct TrustedDevice: Codable, Equatable, Identifiable {
    var id: String { deviceId }

    let deviceId: String
    let deviceName: String
    let platform: String
    let publicKey: String
    let pairingToken: String
    let pairedAt: Date
    let lastSeenAt: Date?
    let trustStatus: TrustStatus
}

enum TrustStatus: String, Codable {
    case trusted
    case revoked
}

struct PairedDeviceSession: Codable, Equatable {
    let host: String
    let port: Int
    let device: TrustedDevice
}

protocol PairedDeviceSessionStore {
    func save(_ session: PairedDeviceSession) throws
    func load() throws -> PairedDeviceSession?
    func clear() throws
}

final class FilePairedDeviceSessionStore: PairedDeviceSessionStore {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultStoreURL(fileManager: fileManager)
    }

    func save(_ session: PairedDeviceSession) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.pairedDeviceSessionEncoder.encode(session)
        try data.write(to: fileURL, options: [.atomic])
    }

    func load() throws -> PairedDeviceSession? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.pairedDeviceSessionDecoder.decode(PairedDeviceSession.self, from: data)
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
            .appendingPathComponent("paired-device-session.json", isDirectory: false)
    }
}

private extension JSONEncoder {
    static var pairedDeviceSessionEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var pairedDeviceSessionDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
