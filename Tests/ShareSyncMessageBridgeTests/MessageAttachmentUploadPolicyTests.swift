import XCTest
@testable import ShareSyncMessageBridge

final class MessageAttachmentUploadPolicyTests: XCTestCase {
    func testUploadsAreRejectedBeforeFileAccessWhenDisabled() {
        let candidate = MessageAttachmentCandidate(
            fileURL: URL(fileURLWithPath: "/does/not/exist.jpg"),
            mimeType: "image/jpeg"
        )

        XCTAssertThrowsError(
            try MessageAttachmentUploadPolicy().validate(
                [candidate],
                attachmentRoot: URL(fileURLWithPath: "/also/missing")
            )
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .uploadsDisabled)
        }
    }

    func testAllowsRegularJPEGAndPNGWithinRoot() throws {
        let root = try makeDirectory()
        let jpeg = try writeFile(in: root, name: "photo.jpg", byteCount: 4)
        let png = try writeFile(in: root, name: "image.png", byteCount: 6)
        let policy = MessageAttachmentUploadPolicy(isEnabled: true)

        let result = try policy.validate(
            [
                MessageAttachmentCandidate(fileURL: jpeg, mimeType: "IMAGE/JPEG"),
                MessageAttachmentCandidate(fileURL: png, mimeType: "image/png"),
            ],
            attachmentRoot: root
        )

        XCTAssertEqual(result.map(\.byteCount), [4, 6])
        XCTAssertEqual(result.map(\.mimeType), ["image/jpeg", "image/png"])
    }

    func testRejectsOutsideRootAndSymbolicLinks() throws {
        let root = try makeDirectory()
        let outsideRoot = try makeDirectory()
        let outsideFile = try writeFile(in: outsideRoot, name: "outside.jpg", byteCount: 4)
        let link = root.appendingPathComponent("linked.jpg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outsideFile)
        let policy = MessageAttachmentUploadPolicy(isEnabled: true)

        XCTAssertThrowsError(
            try policy.validate(
                [MessageAttachmentCandidate(fileURL: outsideFile, mimeType: "image/jpeg")],
                attachmentRoot: root
            )
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .outsideAttachmentRoot)
        }
        XCTAssertThrowsError(
            try policy.validate(
                [MessageAttachmentCandidate(fileURL: link, mimeType: "image/jpeg")],
                attachmentRoot: root
            )
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .symbolicLink)
        }
    }

    func testRejectsUnsupportedTypeAndConfiguredLimits() throws {
        let root = try makeDirectory()
        let first = try writeFile(in: root, name: "first.jpg", byteCount: 6)
        let second = try writeFile(in: root, name: "second.png", byteCount: 6)
        let policy = MessageAttachmentUploadPolicy(
            isEnabled: true,
            maximumFileBytes: 8,
            maximumAttachmentsPerMessage: 2,
            maximumMessageBytes: 10
        )

        XCTAssertThrowsError(
            try policy.validate(
                [MessageAttachmentCandidate(fileURL: first, mimeType: "application/pdf")],
                attachmentRoot: root
            )
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .unsupportedMIMEType)
        }
        XCTAssertThrowsError(
            try policy.validate(
                [
                    MessageAttachmentCandidate(fileURL: first, mimeType: "image/jpeg"),
                    MessageAttachmentCandidate(fileURL: second, mimeType: "image/png"),
                ],
                attachmentRoot: root
            )
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .messageTooLarge)
        }
        XCTAssertThrowsError(
            try MessageAttachmentUploadPolicy(
                isEnabled: true,
                maximumFileBytes: 5
            ).validate(
                [MessageAttachmentCandidate(fileURL: first, mimeType: "image/jpeg")],
                attachmentRoot: root
            )
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .fileTooLarge)
        }

        XCTAssertThrowsError(
            try MessageAttachmentUploadPolicy(
                isEnabled: true,
                maximumAttachmentsPerMessage: 1
            ).validate(
                [
                    MessageAttachmentCandidate(fileURL: first, mimeType: "image/jpeg"),
                    MessageAttachmentCandidate(fileURL: second, mimeType: "image/png"),
                ],
                attachmentRoot: root
            )
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .tooManyAttachments)
        }
    }

    func testRejectsDirectoryAndNonFileURLCandidates() throws {
        let root = try makeDirectory()
        let nestedDirectory = root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(
            at: nestedDirectory,
            withIntermediateDirectories: false
        )
        let policy = MessageAttachmentUploadPolicy(isEnabled: true)

        XCTAssertThrowsError(
            try policy.validate(
                [MessageAttachmentCandidate(fileURL: nestedDirectory, mimeType: "image/jpeg")],
                attachmentRoot: root
            )
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .notRegularFile)
        }
        XCTAssertThrowsError(
            try policy.validate(
                [
                    MessageAttachmentCandidate(
                        fileURL: URL(string: "https://example.com/image.jpg")!,
                        mimeType: "image/jpeg"
                    ),
                ],
                attachmentRoot: root
            )
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .outsideAttachmentRoot)
        }
    }

    func testPostReadSizeMustMatchValidatedMetadata() throws {
        let root = try makeDirectory()
        let file = try writeFile(in: root, name: "photo.jpg", byteCount: 4)
        let policy = MessageAttachmentUploadPolicy(isEnabled: true)
        let attachment = try XCTUnwrap(policy.validate(
            [MessageAttachmentCandidate(fileURL: file, mimeType: "image/jpeg")],
            attachmentRoot: root
        ).first)

        XCTAssertNoThrow(try policy.validateReadByteCount(4, for: attachment))
        XCTAssertThrowsError(try policy.validateReadByteCount(5, for: attachment)) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .fileChanged)
        }
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func writeFile(in directory: URL, name: String, byteCount: Int) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(repeating: 0x41, count: byteCount).write(to: url)
        return url
    }
}
