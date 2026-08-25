import Foundation
import XCTest
@testable import ShareSync

final class ManifestClientTests: XCTestCase {
    func testFetchManifestSendsPairingTokenHeader() async throws {
        let session = StubManifestFetchingSession(data: try fixtureData("sample-manifest", extension: "json"))
        let client = ManifestClient(session: session)

        _ = try await client.fetchManifest(
            from: "192.168.1.10",
            port: 48291,
            pairingToken: "pairing-token-001"
        )

        let request = try XCTUnwrap(session.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://192.168.1.10:48291/v1/manifest")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-ShareSync-Pairing-Token"),
            "pairing-token-001"
        )
    }

    func testFetchManifestRejectsNonSuccessfulStatusCode() async {
        let session = StubManifestFetchingSession(data: Data(), statusCode: 401)
        let client = ManifestClient(session: session)

        do {
            _ = try await client.fetchManifest(from: "192.168.1.10", port: 48291)
            XCTFail("Expected fetchManifest to throw.")
        } catch {
            XCTAssertEqual(error as? ManifestClientError, .unacceptableStatusCode(401))
        }
    }
}

private final class StubManifestFetchingSession: ManifestFetchingSession {
    private let data: Data
    private let statusCode: Int
    private(set) var requests: [URLRequest] = []

    init(data: Data, statusCode: Int = 200) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        return (
            data,
            HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}
