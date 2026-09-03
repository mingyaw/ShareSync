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

struct PairedDeviceEndpoint: Codable, Equatable {
    let host: String
    let port: Int
    let updatedAt: Date
}

enum TrustStatus: String, Codable {
    case trusted
    case revoked
}

struct PairedDeviceSession: Codable, Equatable {
    let lastKnownEndpoint: PairedDeviceEndpoint
    let device: TrustedDevice

    var host: String { lastKnownEndpoint.host }
    var port: Int { lastKnownEndpoint.port }

    init(host: String, port: Int, device: TrustedDevice, endpointUpdatedAt: Date = Date()) {
        self.lastKnownEndpoint = PairedDeviceEndpoint(
            host: host,
            port: port,
            updatedAt: endpointUpdatedAt
        )
        self.device = device
    }

    init(lastKnownEndpoint: PairedDeviceEndpoint, device: TrustedDevice) {
        self.lastKnownEndpoint = lastKnownEndpoint
        self.device = device
    }

    enum CodingKeys: String, CodingKey {
        case host
        case port
        case lastKnownEndpoint
        case device
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device = try container.decode(TrustedDevice.self, forKey: .device)
        if let endpoint = try container.decodeIfPresent(PairedDeviceEndpoint.self, forKey: .lastKnownEndpoint) {
            lastKnownEndpoint = endpoint
            return
        }

        lastKnownEndpoint = PairedDeviceEndpoint(
            host: try container.decode(String.self, forKey: .host),
            port: try container.decode(Int.self, forKey: .port),
            updatedAt: device.pairedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lastKnownEndpoint, forKey: .lastKnownEndpoint)
        try container.encode(lastKnownEndpoint.host, forKey: .host)
        try container.encode(lastKnownEndpoint.port, forKey: .port)
        try container.encode(device, forKey: .device)
    }
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
