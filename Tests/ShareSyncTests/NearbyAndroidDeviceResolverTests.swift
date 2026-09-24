import Foundation
import XCTest
@testable import ShareSync

final class NearbyAndroidDeviceResolverTests: XCTestCase {
    func testResolvesAndroidAdvertisementWithReadableName() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let device = try XCTUnwrap(
            NearbyAndroidDeviceResolver().resolve(
                serviceName: "ShareSync fallback phone",
                hostName: "android-phone.local.",
                port: 48291,
                attributes: [
                    "deviceId": Data("android-device-001".utf8),
                    "deviceName": Data("Pixel 10".utf8),
                    "platform": Data("android".utf8),
                    "version": Data("1".utf8),
                ],
                now: now
            )
        )

        XCTAssertEqual(device.deviceId, "android-device-001")
        XCTAssertEqual(device.deviceName, "Pixel 10")
        XCTAssertEqual(device.endpoint.host, "android-phone.local.")
        XCTAssertEqual(device.endpoint.port, 48291)
        XCTAssertEqual(device.endpoint.updatedAt, now)
    }

    func testFallsBackToBonjourServiceNameForLegacyAdvertisement() throws {
        let device = try XCTUnwrap(
            NearbyAndroidDeviceResolver().resolve(
                serviceName: "ShareSync Galaxy S26",
                hostName: "galaxy.local.",
                port: 48291,
                attributes: [
                    "deviceId": Data("android-device-002".utf8),
                    "platform": Data("android".utf8),
                ]
            )
        )

        XCTAssertEqual(device.deviceName, "Galaxy S26")
    }

    func testRejectsNonAndroidAndIncompleteAdvertisements() {
        let resolver = NearbyAndroidDeviceResolver()

        XCTAssertNil(
            resolver.resolve(
                serviceName: "ShareSync Mac",
                hostName: "mac.local.",
                port: 48291,
                attributes: [
                    "deviceId": Data("mac-device-001".utf8),
                    "platform": Data("macos".utf8),
                ]
            )
        )
        XCTAssertNil(
            resolver.resolve(
                serviceName: "ShareSync Android",
                hostName: nil,
                port: 48291,
                attributes: [
                    "deviceId": Data("android-device-003".utf8),
                    "platform": Data("android".utf8),
                ]
            )
        )
    }
}
