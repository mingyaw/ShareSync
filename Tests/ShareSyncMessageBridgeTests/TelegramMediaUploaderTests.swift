import XCTest
@testable import ShareSyncMessageBridge

final class TelegramMediaUploaderTests: XCTestCase {
    func testUploaderPostsMultipartOnlyToTelegramWithGenericFilename() throws {
        let fixture = try makeValidatedAttachment(
            name: "private-family-photo.jpg",
            mimeType: "image/jpeg",
            data: Data("secret-media".utf8)
        )
        let transport = MediaRecordingTelegramTransport(response: successResponse())
        let uploader = TelegramBotMediaUploader(
            configuration: try configuration(),
            policy: fixture.policy,
            transport: transport,
            boundary: "ShareSyncTestBoundary"
        )

        XCTAssertEqual(try uploader.uploadPhoto(fixture.attachment, data: fixture.data), 901)

        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.scheme, "https")
        XCTAssertEqual(request.url?.host, "api.telegram.org")
        XCTAssertEqual(request.url?.lastPathComponent, "sendPhoto")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Content-Type"),
            "multipart/form-data; boundary=ShareSyncTestBoundary"
        )
        let body = try XCTUnwrap(request.httpBody)
        let text = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(text.contains("name=\"chat_id\""))
        XCTAssertTrue(text.contains("-1001234567890"))
        XCTAssertTrue(text.contains("filename=\"sharesync.jpg\""))
        XCTAssertTrue(text.contains("Content-Type: image/jpeg"))
        XCTAssertTrue(text.contains("secret-media"))
        XCTAssertFalse(text.contains("private-family-photo.jpg"))
        XCTAssertFalse(text.contains(fixture.attachment.fileURL.path))
    }

    func testDisabledPolicyRejectsPreviouslyValidatedAttachmentBeforeTransport() throws {
        let fixture = try makeValidatedAttachment(
            name: "photo.png",
            mimeType: "image/png",
            data: Data("png-data".utf8)
        )
        let transport = MediaRecordingTelegramTransport(response: successResponse())
        let uploader = TelegramBotMediaUploader(
            configuration: try configuration(),
            policy: MessageAttachmentUploadPolicy(),
            transport: transport,
            boundary: "ShareSyncTestBoundary"
        )

        XCTAssertThrowsError(
            try uploader.uploadPhoto(fixture.attachment, data: fixture.data)
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .uploadsDisabled)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testChangedDataSizeIsRejectedBeforeTransport() throws {
        let fixture = try makeValidatedAttachment(
            name: "photo.jpg",
            mimeType: "image/jpeg",
            data: Data("original".utf8)
        )
        let transport = MediaRecordingTelegramTransport(response: successResponse())
        let uploader = TelegramBotMediaUploader(
            configuration: try configuration(),
            policy: fixture.policy,
            transport: transport,
            boundary: "ShareSyncTestBoundary"
        )

        XCTAssertThrowsError(
            try uploader.uploadPhoto(fixture.attachment, data: Data("changed-size".utf8))
        ) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .fileChanged)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testUploaderMapsTelegramRateLimit() throws {
        let fixture = try makeValidatedAttachment(
            name: "photo.jpg",
            mimeType: "image/jpeg",
            data: Data("photo".utf8)
        )
        let responseData = try JSONSerialization.data(withJSONObject: [
            "ok": false,
            "error_code": 429,
            "description": "Too Many Requests",
            "parameters": ["retry_after": 19],
        ])
        let transport = MediaRecordingTelegramTransport(
            response: TelegramBotHTTPResponse(statusCode: 429, data: responseData)
        )
        let uploader = TelegramBotMediaUploader(
            configuration: try configuration(),
            policy: fixture.policy,
            transport: transport,
            boundary: "ShareSyncTestBoundary"
        )

        XCTAssertThrowsError(
            try uploader.uploadPhoto(fixture.attachment, data: fixture.data)
        ) { error in
            XCTAssertEqual(error as? TelegramBotConnectorError, .rateLimited(retryAfter: 19))
        }
    }

    private func configuration() throws -> TelegramBotConfiguration {
        try TelegramBotConfiguration(
            token: "123456:abcdefghijklmnopqrstuvwxyz_ABC",
            chatID: "-1001234567890"
        )
    }

    private func successResponse() -> TelegramBotHTTPResponse {
        TelegramBotHTTPResponse(
            statusCode: 200,
            data: Data(#"{"ok":true,"result":{"message_id":901}}"#.utf8)
        )
    }

    private func makeValidatedAttachment(
        name: String,
        mimeType: String,
        data: Data
    ) throws -> (
        policy: MessageAttachmentUploadPolicy,
        attachment: ValidatedMessageAttachment,
        data: Data
    ) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent(name)
        try data.write(to: fileURL)
        let policy = MessageAttachmentUploadPolicy(isEnabled: true)
        let attachment = try XCTUnwrap(policy.validate(
            [MessageAttachmentCandidate(fileURL: fileURL, mimeType: mimeType)],
            attachmentRoot: root
        ).first)
        return (policy, attachment, data)
    }
}

private final class MediaRecordingTelegramTransport: TelegramBotTransport {
    let response: TelegramBotHTTPResponse
    private(set) var requests: [URLRequest] = []

    init(response: TelegramBotHTTPResponse) {
        self.response = response
    }

    func execute(_ request: URLRequest) throws -> TelegramBotHTTPResponse {
        requests.append(request)
        return response
    }
}
