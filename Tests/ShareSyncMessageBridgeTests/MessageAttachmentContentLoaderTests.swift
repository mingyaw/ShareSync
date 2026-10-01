import XCTest
@testable import ShareSyncMessageBridge

final class MessageAttachmentContentLoaderTests: XCTestCase {
    func testAllowedAttachmentIsRevalidatedAndReadWithinBound() throws {
        let fixture = try makeAttachment(data: Data("image-bytes".utf8))
        let policy = MessageAttachmentUploadPolicy(isEnabled: true)
        let attachment = try XCTUnwrap(policy.validate(
            [fixture.candidate],
            attachmentRoot: fixture.root
        ).first)
        let loader = MessageAttachmentContentLoader(
            policy: policy,
            attachmentRoot: fixture.root,
            readChunkBytes: 3
        )

        let loaded = try XCTUnwrap(loader.load([attachment]).first)

        XCTAssertEqual(loaded.attachment, attachment)
        XCTAssertEqual(loaded.data, Data("image-bytes".utf8))
    }

    func testChangedFileIsRejectedBeforeReturningBytes() throws {
        let fixture = try makeAttachment(data: Data("original".utf8))
        let policy = MessageAttachmentUploadPolicy(isEnabled: true)
        let attachment = try XCTUnwrap(policy.validate(
            [fixture.candidate],
            attachmentRoot: fixture.root
        ).first)
        try Data("larger-content".utf8).write(to: fixture.candidate.fileURL)
        let loader = MessageAttachmentContentLoader(
            policy: policy,
            attachmentRoot: fixture.root
        )

        XCTAssertThrowsError(try loader.load([attachment])) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .fileChanged)
        }
    }

    func testDisabledPolicyRejectsBeforeOpeningValidatedFile() throws {
        let fixture = try makeAttachment(data: Data("image".utf8))
        let enabledPolicy = MessageAttachmentUploadPolicy(isEnabled: true)
        let attachment = try XCTUnwrap(enabledPolicy.validate(
            [fixture.candidate],
            attachmentRoot: fixture.root
        ).first)
        try FileManager.default.removeItem(at: fixture.candidate.fileURL)
        let loader = MessageAttachmentContentLoader(
            policy: MessageAttachmentUploadPolicy(),
            attachmentRoot: fixture.root
        )

        XCTAssertThrowsError(try loader.load([attachment])) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .uploadsDisabled)
        }
    }

    func testDeniedEventDoesNotRequestAttachmentCandidates() throws {
        let provider = RecordingAttachmentCandidateProvider(candidates: [])
        let coordinator = MessageAttachmentAccessCoordinator(
            forwardingPolicy: MessageForwardingPolicy(
                allowedSenderIdentifiers: ["allowed-sender"]
            ),
            candidateProvider: provider,
            uploadPolicy: MessageAttachmentUploadPolicy(isEnabled: true),
            attachmentRoot: FileManager.default.temporaryDirectory
        )

        XCTAssertThrowsError(
            try coordinator.loadAttachments(for: event(sender: "blocked-sender"))
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentAccessError, .eventNotAllowed)
        }
        XCTAssertEqual(provider.requestedRowIDs, [])
    }

    func testAllowedEventLoadsCandidatesOnlyAfterForwardingPolicy() throws {
        let fixture = try makeAttachment(data: Data("image".utf8))
        let provider = RecordingAttachmentCandidateProvider(candidates: [fixture.candidate])
        let coordinator = MessageAttachmentAccessCoordinator(
            forwardingPolicy: MessageForwardingPolicy(
                allowedSenderIdentifiers: ["allowed-sender"],
                allowedConversationIdentifiers: ["allowed-chat"]
            ),
            candidateProvider: provider,
            uploadPolicy: MessageAttachmentUploadPolicy(isEnabled: true),
            attachmentRoot: fixture.root
        )

        let loaded = try coordinator.loadAttachments(
            for: event(sender: "allowed-sender", conversation: "allowed-chat")
        )

        XCTAssertEqual(provider.requestedRowIDs, [42])
        XCTAssertEqual(loaded.map(\.data), [Data("image".utf8)])
    }

    func testAttachmentEventWithoutCandidatesFailsClosed() throws {
        let provider = RecordingAttachmentCandidateProvider(candidates: [])
        let coordinator = MessageAttachmentAccessCoordinator(
            forwardingPolicy: MessageForwardingPolicy(
                allowedSenderIdentifiers: ["allowed-sender"]
            ),
            candidateProvider: provider,
            uploadPolicy: MessageAttachmentUploadPolicy(isEnabled: true),
            attachmentRoot: FileManager.default.temporaryDirectory
        )

        XCTAssertThrowsError(
            try coordinator.loadAttachments(for: event(sender: "allowed-sender"))
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentAccessError, .noAttachmentCandidates)
        }
    }

    private func event(
        sender: String,
        conversation: String = "allowed-chat"
    ) -> NormalizedMessageEvent {
        NormalizedMessageEvent(
            deliveryKey: "opaque-key",
            sourceRowID: 42,
            sourceGUID: "synthetic-guid",
            body: nil,
            timestamp: Date(timeIntervalSince1970: 1_000),
            direction: .incoming,
            senderIdentifier: sender,
            conversationIdentifiers: [conversation],
            service: "iMessage",
            contentKinds: [.attachment],
            associatedMessageGUID: nil,
            attachmentCount: 1,
            attachmentMIMETypes: ["image/jpeg"]
        )
    }

    private func makeAttachment(
        data: Data
    ) throws -> (root: URL, candidate: MessageAttachmentCandidate) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("private-photo.jpg")
        try data.write(to: fileURL)
        return (
            root,
            MessageAttachmentCandidate(fileURL: fileURL, mimeType: "image/jpeg")
        )
    }
}

private final class RecordingAttachmentCandidateProvider: MessageAttachmentCandidateProviding {
    let candidatesToReturn: [MessageAttachmentCandidate]
    private(set) var requestedRowIDs: [Int64] = []

    init(candidates: [MessageAttachmentCandidate]) {
        self.candidatesToReturn = candidates
    }

    func candidates(forMessageRowID rowID: Int64) throws -> [MessageAttachmentCandidate] {
        requestedRowIDs.append(rowID)
        return candidatesToReturn
    }
}
