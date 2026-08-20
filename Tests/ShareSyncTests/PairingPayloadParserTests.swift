import Foundation
import XCTest
@testable import ShareSync

final class PairingPayloadParserTests: XCTestCase {
    func testParseValidPayload() throws {
        let data = try fixtureData("sample-pairing-payload", extension: "json")
        let payload = try PairingPayloadParser().parse(
            data,
            now: ISO8601DateFormatter().date(from: "2026-08-19T06:00:00Z")!
        )

        XCTAssertEqual(payload.version, 1)
        XCTAssertEqual(payload.type, "sharesync_pairing")
        XCTAssertEqual(payload.deviceId, "android-demo-device")
        XCTAssertEqual(payload.platform, "android")
        XCTAssertEqual(payload.ip, "192.168.1.20")
        XCTAssertEqual(payload.port, 48291)
    }

    func testRejectsExpiredPayload() throws {
        let data = try fixtureData("sample-pairing-payload", extension: "json")

        XCTAssertThrowsError(
            try PairingPayloadParser().parse(
                data,
                now: ISO8601DateFormatter().date(from: "2100-01-01T00:00:00Z")!
            )
        ) { error in
            XCTAssertEqual(error as? PairingPayloadParserError, .expired)
        }
    }

    func testRejectsNonAndroidPayload() throws {
        var payload = try JSONSerialization.jsonObject(
            with: try fixtureData("sample-pairing-payload", extension: "json")
        ) as! [String: Any]
        payload["platform"] = "ios"
        let data = try JSONSerialization.data(withJSONObject: payload)

        XCTAssertThrowsError(try PairingPayloadParser().parse(data)) { error in
            XCTAssertEqual(error as? PairingPayloadParserError, .invalidType)
        }
    }
}

