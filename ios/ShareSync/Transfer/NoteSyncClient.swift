import Foundation
#if SWIFT_PACKAGE
import ShareSyncNotes
#endif

enum NoteSyncClientError: Error, Equatable {
    case invalidBaseURL
    case nonHTTPResponse
    case unacceptableStatusCode(Int)
    case mismatchedBatchID
}

struct NoteMergeAcknowledgement: Decodable, Equatable {
    let status: String
    let batchId: String
    let acceptedRemoteCount: Int
    let keptLocalCount: Int
    let unchangedCount: Int
    let conflictCount: Int
    let conflictCopyCount: Int
}

struct NoteSyncCycleResult: Equatable {
    let peerDeviceID: String
    let pulledBatchID: String
    let pushedBatchID: String
    let pullMerge: NoteMergeBatchResult
    let pushAcknowledgement: NoteMergeAcknowledgement
}

final class NoteSyncClient {
    private let session: ManifestFetchingSession?
    private let requestSigner: RequestSigner
    private let codec: NoteSyncBatchCodec
    private let batchIDProvider: () -> String
    private let clock: () -> Int64
    private let retryDelayNanoseconds: UInt64

    init(
        session: ManifestFetchingSession? = nil,
        requestSigner: RequestSigner = RequestSigner(),
        codec: NoteSyncBatchCodec = NoteSyncBatchCodec(),
        batchIDProvider: @escaping () -> String = { UUID().uuidString.lowercased() },
        clock: @escaping () -> Int64 = {
            Int64((Date().timeIntervalSince1970 * 1_000).rounded(.down))
        },
        retryDelayNanoseconds: UInt64 = 500_000_000
    ) {
        self.session = session
        self.requestSigner = requestSigner
        self.codec = codec
        self.batchIDProvider = batchIDProvider
        self.clock = clock
        self.retryDelayNanoseconds = retryDelayNanoseconds
    }

    func fetchSnapshot(
        host: String,
        port: Int,
        signingContext: RequestSigningContext,
        transportSecurity: PairingTransportSecurity? = nil,
    ) async throws -> NoteSyncBatch {
        var request = try makeRequest(
            host: host,
            port: port,
            method: "GET",
            transportSecurity: transportSecurity
        )
        requestSigner.sign(request: &request, context: signingContext)
        let (data, response) = try await activeSession(transportSecurity).data(for: request)
        try requireStatus(response, expected: 200)
        return try codec.decode(data)
    }

    func pushSnapshot(
        _ batch: NoteSyncBatch,
        host: String,
        port: Int,
        signingContext: RequestSigningContext,
        transportSecurity: PairingTransportSecurity? = nil
    ) async throws -> NoteMergeAcknowledgement {
        let body = try codec.encode(batch)
        var request = try makeRequest(
            host: host,
            port: port,
            method: "POST",
            transportSecurity: transportSecurity
        )
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestSigner.sign(request: &request, context: signingContext, body: body)
        let (data, response) = try await activeSession(transportSecurity).data(for: request)
        try requireStatus(response, expected: 202)
        let acknowledgement = try JSONDecoder().decode(NoteMergeAcknowledgement.self, from: data)
        guard acknowledgement.batchId == batch.batchId else {
            throw NoteSyncClientError.mismatchedBatchID
        }
        return acknowledgement
    }

    func synchronize(
        repository: NoteRepository,
        host: String,
        port: Int,
        signingContext: RequestSigningContext,
        transportSecurity: PairingTransportSecurity? = nil,
        maximumAttempts: Int = 2
    ) async throws -> NoteSyncCycleResult {
        let attempts = max(1, maximumAttempts)
        for attempt in 1...attempts {
            do {
                return try await synchronizeOnce(
                    repository: repository,
                    host: host,
                    port: port,
                    signingContext: signingContext,
                    transportSecurity: transportSecurity
                )
            } catch {
                guard attempt < attempts, Self.isRetryable(error) else { throw error }
                try await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
        }
        preconditionFailure("A note sync cycle must either return or throw")
    }

    private func synchronizeOnce(
        repository: NoteRepository,
        host: String,
        port: Int,
        signingContext: RequestSigningContext,
        transportSecurity: PairingTransportSecurity?
    ) async throws -> NoteSyncCycleResult {
        let remoteBatch = try await fetchSnapshot(
            host: host,
            port: port,
            signingContext: signingContext,
            transportSecurity: transportSecurity
        )
        let pullMerge = try repository.mergeRemoteBatch(remoteBatch)
        let localBatch = try repository.createSyncBatch(
            batchID: batchIDProvider(),
            generatedAtEpochMillis: clock()
        )
        let acknowledgement = try await pushSnapshot(
            localBatch,
            host: host,
            port: port,
            signingContext: signingContext,
            transportSecurity: transportSecurity
        )
        return NoteSyncCycleResult(
            peerDeviceID: remoteBatch.sourceDeviceId,
            pulledBatchID: remoteBatch.batchId,
            pushedBatchID: localBatch.batchId,
            pullMerge: pullMerge,
            pushAcknowledgement: acknowledgement
        )
    }

    private static func isRetryable(_ error: Error) -> Bool {
        if error is URLError { return true }
        if case .unacceptableStatusCode(let statusCode)? = error as? NoteSyncClientError {
            return (500...599).contains(statusCode)
        }
        return false
    }

    private func makeRequest(
        host: String,
        port: Int,
        method: String,
        transportSecurity: PairingTransportSecurity?
    ) throws -> URLRequest {
        guard let url = LocalTransportURLBuilder.url(
            host: host,
            port: port,
            path: "/v1/notes",
            transportSecurity: transportSecurity
        ) else {
            throw NoteSyncClientError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func activeSession(_ transportSecurity: PairingTransportSecurity?) -> ManifestFetchingSession {
        session ?? LocalNetworkURLSessionFactory.shortRequestSession(
            transportSecurity: transportSecurity
        )
    }

    private func requireStatus(_ response: URLResponse, expected: Int) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NoteSyncClientError.nonHTTPResponse
        }
        guard httpResponse.statusCode == expected else {
            throw NoteSyncClientError.unacceptableStatusCode(httpResponse.statusCode)
        }
    }
}
