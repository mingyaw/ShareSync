import Foundation
import XCTest
@testable import ShareSync

final class PairedDeviceSessionStoreTests: XCTestCase {
    func testFileStorePersistsPairedDeviceSession() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncPairedDeviceSessionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("paired-device-session.json")
        let store = FilePairedDeviceSessionStore(fileURL: fileURL)
        let session = makeSession()

        XCTAssertNil(try store.load())

        try store.save(session)

        XCTAssertEqual(try store.load(), session)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testFileStoreClearRemovesPairedDeviceSession() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShareSyncPairedDeviceSessionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("paired-device-session.json")
        let store = FilePairedDeviceSessionStore(fileURL: fileURL)

        try store.save(makeSession())
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try store.clear()

        XCTAssertNil(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private func makeSession() -> PairedDeviceSession {
        PairedDeviceSession(
            host: "192.168.1.20",
            port: 48291,
            device: TrustedDevice(
                deviceId: "android-demo-device",
                deviceName: "Pixel Demo",
                platform: "android",
                publicKey: "m0-public-key",
                pairingToken: "pairing-token-001",
                pairedAt: Date(timeIntervalSince1970: 1),
                lastSeenAt: nil,
                trustStatus: .trusted
            ),
            endpointUpdatedAt: Date(timeIntervalSince1970: 2)
        )
    }
}

extension PairedDeviceSessionStoreTests {
    func testPairedDeviceSessionDecodesLegacyHostAndPort() throws {
        let json = """
        {
          "host": "192.168.1.20",
          "port": 48291,
          "device": {
            "deviceId": "android-demo-device",
            "deviceName": "Pixel Demo",
            "platform": "android",
            "publicKey": "m0-public-key",
            "pairingToken": "pairing-token-001",
            "pairedAt": "1970-01-01T00:00:01Z",
            "lastSeenAt": null,
            "trustStatus": "trusted"
          }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let session = try JSONDecoder.pairedDeviceSessionTestDecoder.decode(PairedDeviceSession.self, from: data)

        XCTAssertEqual(session.host, "192.168.1.20")
        XCTAssertEqual(session.port, 48291)
        XCTAssertEqual(session.lastKnownEndpoint.updatedAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(session.device.deviceId, "android-demo-device")
    }
}

private extension JSONDecoder {
    static var pairedDeviceSessionTestDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
