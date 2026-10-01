import XCTest
@testable import ShareSyncMessageBridge

final class MessageAttachmentSecurityGateTests: XCTestCase {
    func testOutsideRootIsRejectedBeforeTelegramRequest() throws {
        let fixture = try MessageBridgeFixture()
        let root = try makeDirectory(in: fixture.directoryURL, name: "Attachments")
        let outside = fixture.directoryURL.appendingPathComponent("outside.jpg")
        try Data("outside".utf8).write(to: outside)
        let harness = try makeHarness(
            fixture: fixture,
            attachmentRoot: root,
            attachments: [(outside, "image/jpeg")]
        )

        XCTAssertThrowsError(try harness.pipeline.run()) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .outsideAttachmentRoot)
        }
        XCTAssertTrue(harness.transport.requests.isEmpty)
        XCTAssertEqual(try harness.cursor.load(), MessageCursor(rowID: 0))
    }

    func testSymbolicLinkIsRejectedBeforeTelegramRequest() throws {
        let fixture = try MessageBridgeFixture()
        let root = try makeDirectory(in: fixture.directoryURL, name: "Attachments")
        let target = fixture.directoryURL.appendingPathComponent("target.jpg")
        try Data("target".utf8).write(to: target)
        let link = root.appendingPathComponent("linked.jpg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let harness = try makeHarness(
            fixture: fixture,
            attachmentRoot: root,
            attachments: [(link, "image/jpeg")]
        )

        XCTAssertThrowsError(try harness.pipeline.run()) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .symbolicLink)
        }
        XCTAssertTrue(harness.transport.requests.isEmpty)
        XCTAssertEqual(try harness.cursor.load(), MessageCursor(rowID: 0))
    }

    func testUnsupportedTypeAndOversizedFileAreRejectedBeforeTelegramRequest() throws {
        for scenario in [
            (mimeType: "application/pdf", data: Data("small".utf8)),
            (mimeType: "image/jpeg", data: Data(repeating: 0x41, count: 9)),
        ] {
            let fixture = try MessageBridgeFixture()
            let root = try makeDirectory(in: fixture.directoryURL, name: "Attachments")
            let file = root.appendingPathComponent("private-file.jpg")
            try scenario.data.write(to: file)
            let harness = try makeHarness(
                fixture: fixture,
                attachmentRoot: root,
                attachments: [(file, scenario.mimeType)],
                uploadPolicy: MessageAttachmentUploadPolicy(
                    isEnabled: true,
                    maximumFileBytes: 8
                )
            )

            XCTAssertThrowsError(try harness.pipeline.run())
            XCTAssertTrue(harness.transport.requests.isEmpty)
            XCTAssertEqual(try harness.cursor.load(), MessageCursor(rowID: 0))
        }
    }

    func testAggregateLimitIsRejectedBeforeTelegramRequest() throws {
        let fixture = try MessageBridgeFixture()
        let root = try makeDirectory(in: fixture.directoryURL, name: "Attachments")
        let first = root.appendingPathComponent("first.jpg")
        let second = root.appendingPathComponent("second.png")
        try Data(repeating: 0x41, count: 6).write(to: first)
        try Data(repeating: 0x42, count: 6).write(to: second)
        let harness = try makeHarness(
            fixture: fixture,
            attachmentRoot: root,
            attachments: [(first, "image/jpeg"), (second, "image/png")],
            uploadPolicy: MessageAttachmentUploadPolicy(
                isEnabled: true,
                maximumFileBytes: 8,
                maximumMessageBytes: 10
            )
        )

        XCTAssertThrowsError(try harness.pipeline.run()) { error in
            XCTAssertEqual(error as? MessageAttachmentValidationError, .messageTooLarge)
        }
        XCTAssertTrue(harness.transport.requests.isEmpty)
        XCTAssertEqual(try harness.cursor.load(), MessageCursor(rowID: 0))
    }

    func testAllowedImageRetriesRateLimitWithoutResendingConfirmedText() throws {
        let fixture = try MessageBridgeFixture()
        let root = try makeDirectory(in: fixture.directoryURL, name: "Attachments")
        let image = root.appendingPathComponent("private-family-photo.jpg")
        try Data("synthetic-image".utf8).write(to: image)
        let rateLimitData = try JSONSerialization.data(withJSONObject: [
            "ok": false,
            "error_code": 429,
            "description": "Too Many Requests",
            "parameters": ["retry_after": 7],
        ])
        let transport = QueuedAttachmentTelegramTransport(responses: [
            TelegramBotHTTPResponse(statusCode: 429, data: rateLimitData),
            successResponse(),
        ])
        let harness = try makeHarness(
            fixture: fixture,
            attachmentRoot: root,
            attachments: [(image, "image/jpeg")],
            transport: transport
        )

        XCTAssertThrowsError(try harness.pipeline.run()) { error in
            XCTAssertEqual(error as? TelegramBotConnectorError, .rateLimited(retryAfter: 7))
        }
        XCTAssertEqual(try harness.cursor.load(), MessageCursor(rowID: 0))
        XCTAssertEqual(harness.textConnector.deliveries.count, 1)

        let result = try harness.pipeline.run()

        XCTAssertEqual(result.deliveredCount, 1)
        XCTAssertEqual(try harness.cursor.load(), MessageCursor(rowID: 1))
        XCTAssertEqual(harness.textConnector.deliveries.count, 1)
        XCTAssertEqual(transport.requests.count, 2)
        let request = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(request.url?.scheme, "https")
        XCTAssertEqual(request.url?.host, "api.telegram.org")
        XCTAssertEqual(request.url?.lastPathComponent, "sendPhoto")
        let body = try XCTUnwrap(request.httpBody)
        let bodyText = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertTrue(bodyText.contains("filename=\"sharesync.jpg\""))
        XCTAssertFalse(bodyText.contains("private-family-photo.jpg"))
        XCTAssertFalse(bodyText.contains(image.path))
    }

    private func makeHarness(
        fixture: MessageBridgeFixture,
        attachmentRoot: URL,
        attachments: [(url: URL, mimeType: String)],
        uploadPolicy: MessageAttachmentUploadPolicy = MessageAttachmentUploadPolicy(
            isEnabled: true
        ),
        transport: QueuedAttachmentTelegramTransport? = nil
    ) throws -> Harness {
        try fixture.insertHandle(identifier: "allowed-sender")
        try fixture.insertMessage(
            guid: "attachment-message",
            body: "photo attached",
            hasAttachments: true
        )
        for (offset, attachment) in attachments.enumerated() {
            let rowID = Int64(offset + 1)
            try fixture.insertAttachment(
                rowID: rowID,
                filename: attachment.url.path,
                mimeType: attachment.mimeType
            )
            try fixture.linkAttachment(rowID: rowID, toMessage: 1)
        }
        let cursor = FileMessageCursorStore(
            fileURL: fixture.directoryURL.appendingPathComponent("attachment-cursor.json")
        )
        try cursor.save(MessageCursor(rowID: 0))
        let policy = MessageForwardingPolicy(
            allowedSenderIdentifiers: ["allowed-sender"]
        )
        let selectedTransport = transport ?? QueuedAttachmentTelegramTransport(
            responses: [successResponse()]
        )
        let configuration = try TelegramBotConfiguration(
            token: "123456:abcdefghijklmnopqrstuvwxyz_ABC",
            chatID: "-1001234567890"
        )
        let uploader = TelegramBotMediaUploader(
            configuration: configuration,
            policy: uploadPolicy,
            transport: selectedTransport,
            boundary: "ShareSyncSecurityGate"
        )
        let attachmentDelivery = MessageAttachmentDeliveryCoordinator(
            accessCoordinator: MessageAttachmentAccessCoordinator(
                forwardingPolicy: policy,
                candidateProvider: SQLiteMessageAttachmentCandidateProvider(
                    databaseURL: fixture.databaseURL
                ),
                uploadPolicy: uploadPolicy,
                attachmentRoot: attachmentRoot
            ),
            connector: uploader
        )
        let textConnector = InMemoryMessageForwardingConnector()
        return Harness(
            pipeline: MessageForwardingPipeline(
                reader: MessageEventReader(databaseURL: fixture.databaseURL),
                cursorStore: cursor,
                policy: policy,
                connector: textConnector,
                deliveryLedger: InMemoryMessageDeliveryLedgerStore(),
                attachmentDeliveryCoordinator: attachmentDelivery,
                now: { Date(timeIntervalSince1970: 1_000) }
            ),
            cursor: cursor,
            textConnector: textConnector,
            transport: selectedTransport
        )
    }

    private func makeDirectory(in parent: URL, name: String) throws -> URL {
        let directory = parent.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func successResponse() -> TelegramBotHTTPResponse {
        TelegramBotHTTPResponse(
            statusCode: 200,
            data: Data(#"{"ok":true,"result":{"message_id":901}}"#.utf8)
        )
    }

    private struct Harness {
        let pipeline: MessageForwardingPipeline
        let cursor: FileMessageCursorStore
        let textConnector: InMemoryMessageForwardingConnector
        let transport: QueuedAttachmentTelegramTransport
    }
}

private final class QueuedAttachmentTelegramTransport: TelegramBotTransport {
    private var responses: [TelegramBotHTTPResponse]
    private(set) var requests: [URLRequest] = []

    init(responses: [TelegramBotHTTPResponse]) {
        self.responses = responses
    }

    func execute(_ request: URLRequest) throws -> TelegramBotHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw TelegramBotConnectorError.invalidResponse }
        return responses.removeFirst()
    }
}
