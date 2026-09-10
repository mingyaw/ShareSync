import Foundation
import XCTest
@testable import ShareSync

final class LocalTransportURLBuilderTests: XCTestCase {
    func testLegacyOrSignedHTTPTransportUsesHTTP() throws {
        XCTAssertEqual(LocalTransportURLBuilder.scheme(for: nil), "http")
        XCTAssertEqual(
            LocalTransportURLBuilder.scheme(
                for: PairingTransportSecurity(
                    mode: .signedHTTP,
                    certificateFingerprintSha256: "",
                    certificateFingerprintEncoding: "hex",
                    certificateNotBefore: nil,
                    certificateNotAfter: nil
                )
            ),
            "http"
        )
    }

    func testQrPinnedHTTPSTransportUsesHTTPS() throws {
        XCTAssertEqual(
            LocalTransportURLBuilder.scheme(for: qrPinnedTransportSecurity()),
            "https"
        )
        XCTAssertEqual(
            LocalTransportURLBuilder.url(
                host: "192.168.1.10",
                port: 48291,
                path: "/v1/manifest",
                transportSecurity: qrPinnedTransportSecurity()
            )?.absoluteString,
            "https://192.168.1.10:48291/v1/manifest"
        )
    }

    private func qrPinnedTransportSecurity() -> PairingTransportSecurity {
        PairingTransportSecurity(
            mode: .qrPinnedHTTPS,
            certificateFingerprintSha256: String(repeating: "a", count: 64),
            certificateFingerprintEncoding: "hex",
            certificateNotBefore: nil,
            certificateNotAfter: nil
        )
    }
}
