import Foundation
import ShareSyncNotes
import XCTest
@testable import ShareSync

final class NoteSyncClientTests: XCTestCase {
    func testSynchronizeRetriesTransientPostWithoutDuplicatingNotes() async throws {
        let codec = NoteSyncBatchCodec()
        let remoteBatch = try NoteSyncBatch(
            batchId: "android-batch-001",
            sourceDeviceId: "android-device-001",
            generatedAtEpochMillis: 2_000,
            notes: [try note(id: "android-note", deviceID: "android-device-001")]
        )
        let acknowledgement = Data(
            #"{"status":"accepted","batchId":"mac-batch-001","acceptedRemoteCount":0,"keptLocalCount":0,"unchangedCount":1,"conflictCount":0,"conflictCopyCount":0}"#.utf8
        )
        let session = StubNoteSyncSession(
            responses: [
                (try codec.encode(remoteBatch), 200),
                (Data(), 503),
                (try codec.encode(remoteBatch), 200),
                (acknowledgement, 202),
            ]
        )
        let repository = try NoteRepository(store: InMemoryNoteStore(), deviceID: "mac-device-001")
        let client = NoteSyncClient(
            session: session,
            batchIDProvider: { "mac-batch-001" },
            retryDelayNanoseconds: 0
        )

        let result = try await client.synchronize(
            repository: repository,
            host: "192.168.1.10",
            port: 48291,
            signingContext: RequestSigningContext(
                deviceId: "mac-device-001",
                sessionId: "mac-notes-v1",
                secret: "device-secret"
            )
        )

        XCTAssertEqual(result.pushedBatchID, "mac-batch-001")
        XCTAssertEqual(session.requests.map(\.httpMethod), ["GET", "POST", "GET", "POST"])
        XCTAssertEqual(try repository.allNotes().map(\.id), ["android-note"])
    }

    func testSynchronizePullsMergesAndPushesSignedSnapshot() async throws {
        let codec = NoteSyncBatchCodec()
        let remoteBatch = try NoteSyncBatch(
            batchId: "android-batch-001",
            sourceDeviceId: "android-device-001",
            generatedAtEpochMillis: 2_000,
            notes: [try note(id: "android-note", deviceID: "android-device-001")]
        )
        let acknowledgement = Data(
            """
            {
              "status": "accepted",
              "batchId": "mac-batch-001",
              "acceptedRemoteCount": 1,
              "keptLocalCount": 1,
              "unchangedCount": 0,
              "conflictCount": 0,
              "conflictCopyCount": 0
            }
            """.utf8
        )
        let session = StubNoteSyncSession(
            responses: [
                (try codec.encode(remoteBatch), 200),
                (acknowledgement, 202),
            ]
        )
        let repository = try NoteRepository(
            store: InMemoryNoteStore(
                initialNotes: [try note(id: "mac-note", deviceID: "mac-device-001")]
            ),
            deviceID: "mac-device-001"
        )
        let client = NoteSyncClient(
            session: session,
            requestSigner: RequestSigner(
                timestampProvider: { 1_800_000_000_000 },
                nonceProvider: { "notes-nonce" }
            ),
            batchIDProvider: { "mac-batch-001" },
            clock: { 3_000 }
        )

        let result = try await client.synchronize(
            repository: repository,
            host: "192.168.1.10",
            port: 48291,
            signingContext: RequestSigningContext(
                deviceId: "mac-device-001",
                sessionId: "mac-notes-v1",
                secret: "device-secret"
            )
        )

        XCTAssertEqual(result.pulledBatchID, "android-batch-001")
        XCTAssertEqual(result.pushedBatchID, "mac-batch-001")
        XCTAssertEqual(result.pullMerge.acceptedRemoteCount, 1)
        XCTAssertEqual(try repository.createSyncBatch(batchID: "verify").notes.map(\.id), ["android-note", "mac-note"])
        XCTAssertEqual(session.requests.map(\.httpMethod), ["GET", "POST"])
        XCTAssertEqual(session.requests.map { $0.url?.path }, ["/v1/notes", "/v1/notes"])
        XCTAssertEqual(session.requests[0].value(forHTTPHeaderField: "X-Device-Id"), "mac-device-001")
        XCTAssertNotNil(session.requests[0].value(forHTTPHeaderField: "X-Signature"))
        XCTAssertNotNil(session.requests[1].value(forHTTPHeaderField: "X-Signature"))
        let pushed = try codec.decode(try XCTUnwrap(session.requests[1].httpBody))
        XCTAssertEqual(pushed.sourceDeviceId, "mac-device-001")
        XCTAssertEqual(pushed.generatedAtEpochMillis, 3_000)
        XCTAssertEqual(pushed.notes.map(\.id), ["android-note", "mac-note"])
    }

    func testFetchSnapshotRejectsNonSuccessfulResponse() async {
        let session = StubNoteSyncSession(responses: [(Data(), 401)])
        let client = NoteSyncClient(session: session)

        do {
            _ = try await client.fetchSnapshot(
                host: "192.168.1.10",
                port: 48291,
                signingContext: RequestSigningContext(
                    deviceId: "mac-device-001",
                    sessionId: "mac-notes-v1",
                    secret: "device-secret"
                )
            )
            XCTFail("Expected fetchSnapshot to throw")
        } catch {
            XCTAssertEqual(error as? NoteSyncClientError, .unacceptableStatusCode(401))
        }
    }

    func testPushRejectsAcknowledgementForDifferentBatch() async throws {
        let response = Data(
            #"{"status":"accepted","batchId":"other","acceptedRemoteCount":0,"keptLocalCount":0,"unchangedCount":0,"conflictCount":0,"conflictCopyCount":0}"#.utf8
        )
        let session = StubNoteSyncSession(responses: [(response, 202)])
        let client = NoteSyncClient(session: session)
        let batch = try NoteSyncBatch(
            batchId: "mac-batch-001",
            sourceDeviceId: "mac-device-001",
            generatedAtEpochMillis: 1,
            notes: []
        )

        do {
            _ = try await client.pushSnapshot(
                batch,
                host: "192.168.1.10",
                port: 48291,
                signingContext: RequestSigningContext(
                    deviceId: "mac-device-001",
                    sessionId: "mac-notes-v1",
                    secret: "device-secret"
                )
            )
            XCTFail("Expected pushSnapshot to throw")
        } catch {
            XCTAssertEqual(error as? NoteSyncClientError, .mismatchedBatchID)
        }
    }

    func testPushRejectsOversizedSnapshotBeforeNetworkRequest() async throws {
        let session = StubNoteSyncSession(responses: [])
        let client = NoteSyncClient(session: session, maximumSnapshotBytes: 32)
        let batch = try NoteSyncBatch(
            batchId: "mac-batch-001",
            sourceDeviceId: "mac-device-001",
            generatedAtEpochMillis: 1,
            notes: []
        )

        do {
            _ = try await client.pushSnapshot(
                batch,
                host: "192.168.1.10",
                port: 48291,
                signingContext: RequestSigningContext(
                    deviceId: "mac-device-001",
                    sessionId: "mac-notes-v1",
                    secret: "device-secret"
                )
            )
            XCTFail("Expected pushSnapshot to reject the payload")
        } catch {
            guard case .payloadTooLarge(let byteCount)? = error as? NoteSyncClientError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertGreaterThan(byteCount, 32)
            XCTAssertTrue(session.requests.isEmpty)
        }
    }

    func testFetchRejectsOversizedSnapshotResponse() async {
        let session = StubNoteSyncSession(responses: [(Data(repeating: 0x61, count: 33), 200)])
        let client = NoteSyncClient(session: session, maximumSnapshotBytes: 32)

        do {
            _ = try await client.fetchSnapshot(
                host: "192.168.1.10",
                port: 48291,
                signingContext: RequestSigningContext(
                    deviceId: "mac-device-001",
                    sessionId: "mac-notes-v1",
                    secret: "device-secret"
                )
            )
            XCTFail("Expected fetchSnapshot to reject the payload")
        } catch {
            XCTAssertEqual(error as? NoteSyncClientError, .payloadTooLarge(33))
        }
    }

    private func note(id: String, deviceID: String) throws -> VersionedNote {
        try VersionedNote(
            id: id,
            title: "Shared note",
            markdownBody: "Synced locally.",
            createdAtEpochMillis: 1_000,
            updatedAtEpochMillis: 1_000,
            tags: ["shared"],
            revision: NoteRevision(sequence: 1, deviceId: deviceID),
            parentRevision: nil,
            deletedAtEpochMillis: nil
        )
    }
}

private final class StubNoteSyncSession: ManifestFetchingSession {
    private let responses: [(Data, Int)]
    private(set) var requests: [URLRequest] = []

    init(responses: [(Data, Int)]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let index = requests.count
        requests.append(request)
        let response = responses[index]
        return (
            response.0,
            HTTPURLResponse(
                url: request.url!,
                statusCode: response.1,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }
}
