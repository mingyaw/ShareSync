import Foundation
import XCTest
@testable import ShareSync

final class SyncResultClientTests: XCTestCase {
    func testPostSyncResultSendsJsonToAndroidEndpoint() async throws {
        let session = StubSyncResultPostingSession(statusCode: 202)
        let client = SyncResultClient(session: session)
        let result = makeResult()

        try await client.postSyncResult(
            result,
            to: "192.168.1.10",
            port: 48291,
            pairingToken: "pairing-token-001"
        )

        let request = try XCTUnwrap(session.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://192.168.1.10:48291/v1/sync/result")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-ShareSync-Pairing-Token"),
            "pairing-token-001"
        )

        let body = try XCTUnwrap(request.httpBody)
        let decoded = try JSONDecoder().decode(SyncResult.self, from: body)
        XCTAssertEqual(decoded, result)
    }

    func testPostSyncResultRejectsNonSuccessfulStatusCode() async {
        let session = StubSyncResultPostingSession(statusCode: 500)
        let client = SyncResultClient(session: session)

        do {
            try await client.postSyncResult(makeResult(), to: "192.168.1.10", port: 48291)
            XCTFail("Expected postSyncResult to throw.")
        } catch {
            XCTAssertEqual(error as? SyncResultClientError, .unacceptableStatusCode(500))
        }
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
    private let statusCode: Int
    private(set) var requests: [URLRequest] = []

    init(statusCode: Int) {
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
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
