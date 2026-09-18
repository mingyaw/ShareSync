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

    func testFetchManifestSendsSignedHeaders() async throws {
        let session = StubManifestFetchingSession(data: try fixtureData("sample-manifest", extension: "json"))
        let client = ManifestClient(
            session: session,
            requestSigner: RequestSigner(
                timestampProvider: { 1_800_000_000_000 },
                nonceProvider: { "nonce-001" }
            )
        )

        _ = try await client.fetchManifest(
            from: "192.168.1.10",
            port: 48291,
            pairingToken: "pairing-token-001",
            signingContext: RequestSigningContext(
                deviceId: "ios-local",
                sessionId: "ios-photo-mvp",
                secret: "pairing-token-001"
            )
        )

        let request = try XCTUnwrap(session.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-ShareSync-Version"), "1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-Id"), "ios-local")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Session-Id"), "ios-photo-mvp")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Timestamp"), "1800000000000")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Nonce"), "nonce-001")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Signature"), "V+Zfc9LZCzOl+H/8ZpZGbCjZ2WiZxwo2mgc17pPqPhY=")
    }

    func testFetchAllManifestPagesMergesAssetsAndAdvancesCursor() async throws {
        let firstPage = manifestPageJSON(
            cursor: "media-v1:1002:2",
            assetId: "media-001",
            hasMore: true,
            nextCursor: "page-v2:0:0:1002:2:1"
        )
        let secondPage = manifestPageJSON(
            cursor: "media-v1:1002:2",
            assetId: "media-002",
            hasMore: false,
            nextCursor: nil
        )
        let session = StubManifestFetchingSession(dataSequence: [firstPage, secondPage])
        let client = ManifestClient(session: session)

        let manifest = try await client.fetchAllManifestPages(
            from: "192.168.1.10",
            port: 48291,
            sinceCursor: "media-v1:1000:0"
        )

        XCTAssertEqual(manifest.media.map(\.assetId), ["media-001", "media-002"])
        XCTAssertEqual(session.requests.count, 2)
        XCTAssertEqual(
            session.requests[1].url?.absoluteString,
            "http://192.168.1.10:48291/v1/manifest?sinceCursor=media-v1:1000:0&pageCursor=page-v2:0:0:1002:2:1"
        )
        XCTAssertEqual(manifest.cursor, "media-v1:1002:2")
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

    private func manifestPageJSON(
        cursor: String,
        assetId: String,
        hasMore: Bool,
        nextCursor: String?
    ) -> Data {
        let nextCursorJSON = nextCursor.map { "\"\($0)\"" } ?? "null"
        return Data(
            """
            {
              "version": 1,
              "sourceDeviceId": "android-demo-device",
              "generatedAt": "2026-09-18T00:00:00Z",
              "cursor": "\(cursor)",
              "pageSize": 1,
              "hasMore": \(hasMore),
              "nextCursor": \(nextCursorJSON),
              "media": [{
                "assetId": "\(assetId)",
                "sourceDeviceId": "android-demo-device",
                "mediaType": "photo",
                "fileName": "\(assetId).jpg",
                "mimeType": "image/jpeg",
                "size": 1024
              }],
              "contacts": [],
              "files": []
            }
            """.utf8
        )
    }
}

private final class StubManifestFetchingSession: ManifestFetchingSession {
    private let dataSequence: [Data]
    private let statusCode: Int
    private(set) var requests: [URLRequest] = []

    init(data: Data, statusCode: Int = 200) {
        self.dataSequence = [data]
        self.statusCode = statusCode
    }

    init(dataSequence: [Data], statusCode: Int = 200) {
        self.dataSequence = dataSequence
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let responseIndex = min(requests.count, dataSequence.count - 1)
        requests.append(request)
        return (
            dataSequence[responseIndex],
            HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}
