import Foundation
import XCTest
@testable import ShareSync

final class SyncResultClientTests: XCTestCase {
    func testPostSyncResultSendsJsonToAndroidEndpoint() async throws {
        let session = StubSyncResultPostingSession(statusCode: 202)
        let client = SyncResultClient(
            session: session,
            requestSigner: RequestSigner(
                timestampProvider: { 1_800_000_000_000 },
                nonceProvider: { "nonce-001" }
            )
        )
        let result = makeResult()

        let statusCode = try await client.postSyncResult(
            result,
            to: "192.168.1.10",
            port: 48291,
            pairingToken: "pairing-token-001",
            signingContext: RequestSigningContext(
                deviceId: "ios-local",
                sessionId: "ios-photo-mvp",
                secret: "pairing-token-001"
            )
        )

        XCTAssertEqual(statusCode, 202)
        let request = try XCTUnwrap(session.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://192.168.1.10:48291/v1/sync/result")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-ShareSync-Pairing-Token"),
            "pairing-token-001"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-ShareSync-Version"), "1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device-Id"), "ios-local")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Session-Id"), "ios-photo-mvp")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Timestamp"), "1800000000000")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Nonce"), "nonce-001")

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode(SyncResult.self, from: body)
        XCTAssertEqual(decoded, result)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-Signature"),
            RequestSigner.signature(
                secret: "pairing-token-001",
                method: "POST",
                path: "/v1/sync/result",
                timestamp: "1800000000000",
                nonce: "nonce-001",
                body: body
            )
        )
    }

    func testPostSyncResultRejectsNonSuccessfulStatusCode() async {
        let session = StubSyncResultPostingSession(statusCode: 500)
        let client = SyncResultClient(session: session)

        do {
            _ = try await client.postSyncResult(makeResult(), to: "192.168.1.10", port: 48291)
            XCTFail("Expected postSyncResult to throw.")
        } catch {
            XCTAssertEqual(error as? SyncResultClientError, .unacceptableStatusCode(500))
        }
    }

    func testPostSyncResultCanSucceedAfterPreviousServerFailure() async throws {
        let session = StubSyncResultPostingSession(statusCodes: [500, 202])
        let client = SyncResultClient(session: session)
        let result = makeResult()

        do {
            _ = try await client.postSyncResult(result, to: "192.168.1.10", port: 48291)
            XCTFail("Expected first postSyncResult to throw.")
        } catch {
            XCTAssertEqual(error as? SyncResultClientError, .unacceptableStatusCode(500))
        }

        let statusCode = try await client.postSyncResult(result, to: "192.168.1.10", port: 48291)

        XCTAssertEqual(statusCode, 202)
        XCTAssertEqual(session.requests.count, 2)
    }

    private func makeResult() -> SyncResult {
        SyncResult(
            syncBatchId: "batch-001",
            targetDeviceId: "ios-device-001",
            results: [
                SyncItemResult(
                    itemType: .media,
                    sourceItemId: "media-001",
                    targetItemId: "photo-local-001",
                    status: .synced,
                    errorCode: nil
                )
            ]
        )
    }
}

private final class StubSyncResultPostingSession: SyncResultPostingSession {
    private var statusCodes: [Int]
    private(set) var requests: [URLRequest] = []

    init(statusCode: Int) {
        self.statusCodes = [statusCode]
    }

    init(statusCodes: [Int]) {
        self.statusCodes = statusCodes
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let statusCode = statusCodes.isEmpty ? 200 : statusCodes.removeFirst()
        return (
            Data(),
            HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}
