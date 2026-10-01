import Foundation

public struct LoadedMessageAttachment: Equatable, Sendable {
    public let attachment: ValidatedMessageAttachment
    public let data: Data

    public init(attachment: ValidatedMessageAttachment, data: Data) {
        self.attachment = attachment
        self.data = data
    }
}

public protocol MessageAttachmentCandidateProviding: AnyObject {
    func candidates(forMessageRowID rowID: Int64) throws -> [MessageAttachmentCandidate]
}

public enum MessageAttachmentAccessError: Error, Equatable, Sendable {
    case eventNotAllowed
}

public struct MessageAttachmentContentLoader: Sendable {
    private let policy: MessageAttachmentUploadPolicy
    private let attachmentRoot: URL
    private let readChunkBytes: Int

    public init(
        policy: MessageAttachmentUploadPolicy,
        attachmentRoot: URL,
        readChunkBytes: Int = 64 * 1_024
    ) {
        self.policy = policy
        self.attachmentRoot = attachmentRoot
        self.readChunkBytes = max(1, min(readChunkBytes, 256 * 1_024))
    }

    public func load(
        _ attachments: [ValidatedMessageAttachment]
    ) throws -> [LoadedMessageAttachment] {
        let candidates = attachments.map {
            MessageAttachmentCandidate(fileURL: $0.fileURL, mimeType: $0.mimeType)
        }
        let refreshed = try policy.validate(candidates, attachmentRoot: attachmentRoot)
        guard refreshed == attachments else {
            throw MessageAttachmentValidationError.fileChanged
        }
        return try attachments.map { attachment in
            LoadedMessageAttachment(
                attachment: attachment,
                data: try readBounded(attachment)
            )
        }
    }

    private func readBounded(_ attachment: ValidatedMessageAttachment) throws -> Data {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: attachment.fileURL)
        } catch {
            throw MessageAttachmentValidationError.unreadableAttachment
        }
        defer { try? handle.close() }

        var data = Data()
        while data.count <= attachment.byteCount {
            let remainingIncludingOverflowByte = attachment.byteCount - data.count + 1
            let requestBytes = min(readChunkBytes, remainingIncludingOverflowByte)
            let chunk: Data
            do {
                chunk = try handle.read(upToCount: requestBytes) ?? Data()
            } catch {
                throw MessageAttachmentValidationError.unreadableAttachment
            }
            if chunk.isEmpty { break }
            data.append(chunk)
            guard data.count <= attachment.byteCount else {
                throw MessageAttachmentValidationError.fileChanged
            }
        }
        try policy.validateReadByteCount(data.count, for: attachment)
        return data
    }
}

public struct MessageAttachmentAccessCoordinator {
    private let forwardingPolicy: MessageForwardingPolicy
    private let candidateProvider: any MessageAttachmentCandidateProviding
    private let uploadPolicy: MessageAttachmentUploadPolicy
    private let attachmentRoot: URL
    private let contentLoader: MessageAttachmentContentLoader

    public init(
        forwardingPolicy: MessageForwardingPolicy,
        candidateProvider: any MessageAttachmentCandidateProviding,
        uploadPolicy: MessageAttachmentUploadPolicy,
        attachmentRoot: URL
    ) {
        self.forwardingPolicy = forwardingPolicy
        self.candidateProvider = candidateProvider
        self.uploadPolicy = uploadPolicy
        self.attachmentRoot = attachmentRoot
        self.contentLoader = MessageAttachmentContentLoader(
            policy: uploadPolicy,
            attachmentRoot: attachmentRoot
        )
    }

    public func loadAttachments(
        for event: NormalizedMessageEvent
    ) throws -> [LoadedMessageAttachment] {
        guard event.contentKinds.contains(.attachment) else { return [] }
        guard forwardingPolicy.permits(event) else {
            throw MessageAttachmentAccessError.eventNotAllowed
        }
        let candidates = try candidateProvider.candidates(forMessageRowID: event.sourceRowID)
        let attachments = try uploadPolicy.validate(
            candidates,
            attachmentRoot: attachmentRoot
        )
        return try contentLoader.load(attachments)
    }
}
