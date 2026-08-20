import Foundation
import XCTest
@testable import ShareSync

final class SyncManifestDecodingTests: XCTestCase {
    func testDecodeSampleManifest() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let manifest = try decoder.decode(
            SyncManifest.self,
            from: try fixtureData("sample-manifest", extension: "json")
        )

        XCTAssertEqual(manifest.version, 1)
        XCTAssertEqual(manifest.sourceDeviceId, "android-demo-device")
        XCTAssertEqual(manifest.cursor, "m0-demo-cursor")
        XCTAssertEqual(manifest.media.count, 2)
        XCTAssertEqual(manifest.media[0].mediaType, .photo)
        XCTAssertEqual(manifest.media[1].mediaType, .video)
        XCTAssertEqual(manifest.contacts.count, 0)
        XCTAssertEqual(manifest.files.count, 0)
    }
}

