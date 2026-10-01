import Foundation

public struct MessageAttachmentCandidate: Equatable, Sendable {
    public let fileURL: URL
    public let mimeType: String

    public init(fileURL: URL, mimeType: String) {
        self.fileURL = fileURL
        self.mimeType = mimeType
    }
}

public struct ValidatedMessageAttachment: Equatable, Sendable {
    public let fileURL: URL
    public let mimeType: String
    public let byteCount: Int
}

public enum MessageAttachmentValidationError: Error, Equatable, Sendable {
    case uploadsDisabled
    case invalidAttachmentRoot
    case tooManyAttachments
    case outsideAttachmentRoot
    case symbolicLink
    case notRegularFile
    case unsupportedMIMEType
    case invalidFileSize
    case fileTooLarge
    case messageTooLarge
    case fileChanged
    case unreadableAttachment
}

public struct MessageAttachmentUploadPolicy: Equatable, Sendable {
    public let isEnabled: Bool
    public let allowedMIMETypes: Set<String>
    public let maximumFileBytes: Int
    public let maximumAttachmentsPerMessage: Int
    public let maximumMessageBytes: Int

    public init(
        isEnabled: Bool = false,
        allowedMIMETypes: Set<String> = ["image/jpeg", "image/png"],
        maximumFileBytes: Int = 10 * 1_024 * 1_024,
        maximumAttachmentsPerMessage: Int = 4,
        maximumMessageBytes: Int = 20 * 1_024 * 1_024
    ) {
        self.isEnabled = isEnabled
        self.allowedMIMETypes = Set(allowedMIMETypes.map { $0.lowercased() })
        self.maximumFileBytes = max(maximumFileBytes, 1)
        self.maximumAttachmentsPerMessage = max(maximumAttachmentsPerMessage, 1)
        self.maximumMessageBytes = max(maximumMessageBytes, 1)
    }

    public func validate(
        _ candidates: [MessageAttachmentCandidate],
        attachmentRoot: URL
    ) throws -> [ValidatedMessageAttachment] {
        guard isEnabled else { throw MessageAttachmentValidationError.uploadsDisabled }
        guard candidates.count <= maximumAttachmentsPerMessage else {
            throw MessageAttachmentValidationError.tooManyAttachments
        }

        guard attachmentRoot.isFileURL else {
            throw MessageAttachmentValidationError.invalidAttachmentRoot
        }
        let root = attachmentRoot.standardizedFileURL
        let rootValues = try resourceValues(for: root)
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            throw MessageAttachmentValidationError.invalidAttachmentRoot
        }
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        var totalBytes = 0

        return try candidates.map { candidate in
            let mimeType = candidate.mimeType.lowercased()
            guard allowedMIMETypes.contains(mimeType) else {
                throw MessageAttachmentValidationError.unsupportedMIMEType
            }

            guard candidate.fileURL.isFileURL else {
                throw MessageAttachmentValidationError.outsideAttachmentRoot
            }
            let fileURL = candidate.fileURL.standardizedFileURL
            guard isDescendant(fileURL, of: root) else {
                throw MessageAttachmentValidationError.outsideAttachmentRoot
            }
            try rejectSymbolicLinks(between: root, and: fileURL)

            let canonicalFile = fileURL.resolvingSymlinksInPath().standardizedFileURL
            guard isDescendant(canonicalFile, of: canonicalRoot) else {
                throw MessageAttachmentValidationError.outsideAttachmentRoot
            }
            let values = try resourceValues(for: canonicalFile)
            guard values.isRegularFile == true else {
                throw MessageAttachmentValidationError.notRegularFile
            }
            guard let byteCount = values.fileSize, byteCount > 0 else {
                throw MessageAttachmentValidationError.invalidFileSize
            }
            guard byteCount <= maximumFileBytes else {
                throw MessageAttachmentValidationError.fileTooLarge
            }
            totalBytes += byteCount
            guard totalBytes <= maximumMessageBytes else {
                throw MessageAttachmentValidationError.messageTooLarge
            }

            return ValidatedMessageAttachment(
                fileURL: canonicalFile,
                mimeType: mimeType,
                byteCount: byteCount
            )
        }
    }

    public func validateReadByteCount(
        _ byteCount: Int,
        for attachment: ValidatedMessageAttachment
    ) throws {
        guard byteCount == attachment.byteCount else {
            throw MessageAttachmentValidationError.fileChanged
        }
        guard byteCount > 0 else {
            throw MessageAttachmentValidationError.invalidFileSize
        }
        guard byteCount <= maximumFileBytes else {
            throw MessageAttachmentValidationError.fileTooLarge
        }
    }

    private func rejectSymbolicLinks(between root: URL, and file: URL) throws {
        let rootComponents = root.pathComponents
        let fileComponents = file.pathComponents
        guard fileComponents.starts(with: rootComponents) else {
            throw MessageAttachmentValidationError.outsideAttachmentRoot
        }

        var current = root
        for component in fileComponents.dropFirst(rootComponents.count) {
            current.appendPathComponent(component)
            if try resourceValues(for: current).isSymbolicLink == true {
                throw MessageAttachmentValidationError.symbolicLink
            }
        }
    }

    private func resourceValues(for url: URL) throws -> URLResourceValues {
        do {
            return try url.resourceValues(forKeys: [
                .isDirectoryKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
            ])
        } catch {
            throw MessageAttachmentValidationError.unreadableAttachment
        }
    }

    private func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path.hasPrefix(rootPath)
    }
}
