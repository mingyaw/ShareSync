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
            )
        )
    }
}
