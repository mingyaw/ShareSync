import Foundation
import XCTest
@testable import ShareSync

final class RequestSignerTests: XCTestCase {
    func testSignatureMatchesSharedFixture() {
        let signature = RequestSigner.signature(
            secret: "pairing-token-001",
            method: "GET",
            path: "/v1/manifest",
            timestamp: "1800000000000",
            nonce: "nonce-001",
            body: Data()
        )

        XCTAssertEqual(signature, "V+Zfc9LZCzOl+H/8ZpZGbCjZ2WiZxwo2mgc17pPqPhY=")
        XCTAssertEqual(
            RequestSigner.sha256Hex(Data()),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testSignAddsRequiredHeaders() throws {
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://192.168.1.10:48291/v1/manifest")))
        let signer = RequestSigner(
            timestampProvider: { 1_800_000_000_000 },
            nonceProvider: { "nonce-001" }
        )

        signer.sign(
            request: &request,
            context: RequestSigningContext(
                deviceId: "ios-local",
                sessionId: "ios-photo-mvp",
                secret: "pairing-token-001"
            )
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "X-ShareSync-Version"), "1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-Id"), "ios-local")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Session-Id"), "ios-photo-mvp")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Timestamp"), "1800000000000")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Nonce"), "nonce-001")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Signature"), "V+Zfc9LZCzOl+H/8ZpZGbCjZ2WiZxwo2mgc17pPqPhY=")
    }
}
