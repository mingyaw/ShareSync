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

    func testFetchHealthDecodesReadyAndroidPeer() async throws {
        let data = Data(
            """
            {
              "status": "ok",
              "deviceId": "android-demo-device",
              "appVersion": "0.1.0",
              "protocolVersion": 1
            }
            """.utf8
        )
        let session = StubManifestFetchingSession(data: data)
        let client = HealthClient(session: session)

        let health = try await client.fetchHealth(from: "192.168.1.10", port: 48291)

        XCTAssertEqual(session.requests.first?.url?.absoluteString, "http://192.168.1.10:48291/v1/health")
        XCTAssertEqual(
            health,
            LocalPeerHealth(
                status: "ok",
                deviceId: "android-demo-device",
                appVersion: "0.1.0",
                protocolVersion: 1
            )
        )
        XCTAssertTrue(health.isReady)
    }

    func testFetchHealthRejectsNonSuccessfulStatusCode() async {
        let session = StubManifestFetchingSession(data: Data(), statusCode: 404)
        let client = HealthClient(session: session)

        do {
            _ = try await client.fetchHealth(from: "192.168.1.10", port: 48291)
            XCTFail("Expected fetchHealth to throw.")
        } catch {
            XCTAssertEqual(error as? HealthClientError, .unacceptableStatusCode(404))
        }
    }

    func testFetchHealthRejectsPeerThatIsNotReady() async {
        let data = Data(
            """
            {
              "status": "starting",
              "deviceId": "android-demo-device",
              "appVersion": "0.1.0",
              "protocolVersion": 1
            }
            """.utf8
        )
        let session = StubManifestFetchingSession(data: data)
        let client = HealthClient(session: session)

        do {
            _ = try await client.fetchHealth(from: "192.168.1.10", port: 48291)
            XCTFail("Expected fetchHealth to throw.")
        } catch {
            XCTAssertEqual(error as? HealthClientError, .peerNotReady("starting"))
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
