import XCTest
@testable import ShareSyncMessageBridge

final class SQLiteMessageAttachmentCandidateProviderTests: XCTestCase {
    func testReturnsOnlyAttachmentsLinkedToRequestedMessageWithoutOpeningFiles() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        try fixture.insertMessage(guid: "first", body: nil, hasAttachments: true)
        try fixture.insertMessage(guid: "second", body: nil, hasAttachments: true)
        try fixture.insertAttachment(
            rowID: 1,
            filename: "/nonexistent/messages/first.jpg",
            mimeType: "image/jpeg"
        )
        try fixture.insertAttachment(
            rowID: 2,
            filename: "/nonexistent/messages/second.png",
            mimeType: "image/png"
        )
        try fixture.linkAttachment(rowID: 1, toMessage: 1)
        try fixture.linkAttachment(rowID: 2, toMessage: 2)
        let provider = SQLiteMessageAttachmentCandidateProvider(databaseURL: fixture.databaseURL)

        let candidates = try provider.candidates(forMessageRowID: 2)

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.fileURL.path, "/nonexistent/messages/second.png")
        XCTAssertEqual(candidates.first?.mimeType, "image/png")
    }

    func testExpandsOnlyLeadingHomeMarkerUsingConfiguredHome() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        try fixture.insertMessage(guid: "message", body: nil, hasAttachments: true)
        try fixture.insertAttachment(
            filename: "~/Library/Messages/Attachments/photo.jpg",
            mimeType: "image/jpeg"
        )
        try fixture.linkAttachment(rowID: 1, toMessage: 1)
        let home = URL(fileURLWithPath: "/synthetic-home", isDirectory: true)
        let provider = SQLiteMessageAttachmentCandidateProvider(
            databaseURL: fixture.databaseURL,
            homeDirectory: home
        )

        let candidate = try XCTUnwrap(provider.candidates(forMessageRowID: 1).first)

        XCTAssertEqual(
            candidate.fileURL.path,
            "/synthetic-home/Library/Messages/Attachments/photo.jpg"
        )
    }

    func testRelativeStoredPathFailsClosed() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle()
        try fixture.insertMessage(guid: "message", body: nil, hasAttachments: true)
        try fixture.insertAttachment(filename: "Attachments/photo.jpg", mimeType: "image/jpeg")
        try fixture.linkAttachment(rowID: 1, toMessage: 1)
        let provider = SQLiteMessageAttachmentCandidateProvider(databaseURL: fixture.databaseURL)

        XCTAssertThrowsError(try provider.candidates(forMessageRowID: 1)) { error in
            XCTAssertEqual(
                error as? MessageAttachmentCandidateProviderError,
                .invalidStoredPath
            )
        }
    }

    func testMissingPathSchemaFailsBeforeQueryingAttachmentRows() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.execute("ALTER TABLE attachment RENAME TO attachment_with_filename")
        try fixture.execute("CREATE TABLE attachment (ROWID INTEGER PRIMARY KEY, mime_type TEXT)")
        let provider = SQLiteMessageAttachmentCandidateProvider(databaseURL: fixture.databaseURL)

        XCTAssertThrowsError(try provider.candidates(forMessageRowID: 1)) { error in
            guard case .unsupportedSchema(let missing) = error as? MessageBridgeError else {
                return XCTFail("Expected unsupported schema")
            }
            XCTAssertTrue(missing.contains("attachment.filename"))
        }
    }

    func testInvalidMessageRowIDFailsBeforeDatabaseAccess() {
        let provider = SQLiteMessageAttachmentCandidateProvider(
            databaseURL: URL(fileURLWithPath: "/database/does/not/exist")
        )

        XCTAssertThrowsError(try provider.candidates(forMessageRowID: 0)) { error in
            XCTAssertEqual(
                error as? MessageAttachmentCandidateProviderError,
                .invalidMessageRowID
            )
        }
    }

    func testAllowedEventCanLoadSyntheticAttachmentThroughReadOnlyProvider() throws {
        let fixture = try MessageBridgeFixture()
        try fixture.insertHandle(identifier: "allowed-sender")
        try fixture.insertMessage(guid: "message", body: nil, hasAttachments: true)
        let attachmentRoot = fixture.directoryURL.appendingPathComponent(
            "Attachments",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: attachmentRoot,
            withIntermediateDirectories: true
        )
        let fileURL = attachmentRoot.appendingPathComponent("photo.jpg")
        try Data("synthetic-photo".utf8).write(to: fileURL)
        try fixture.insertAttachment(
            filename: fileURL.path,
            mimeType: "image/jpeg"
        )
        try fixture.linkAttachment(rowID: 1, toMessage: 1)
        let coordinator = MessageAttachmentAccessCoordinator(
            forwardingPolicy: MessageForwardingPolicy(
                allowedSenderIdentifiers: ["allowed-sender"]
            ),
            candidateProvider: SQLiteMessageAttachmentCandidateProvider(
                databaseURL: fixture.databaseURL
            ),
            uploadPolicy: MessageAttachmentUploadPolicy(isEnabled: true),
            attachmentRoot: attachmentRoot
        )
        let event = NormalizedMessageEvent(
            deliveryKey: "opaque-key",
            sourceRowID: 1,
            sourceGUID: "synthetic-guid",
            body: nil,
            timestamp: Date(timeIntervalSince1970: 1_000),
            direction: .incoming,
            senderIdentifier: "allowed-sender",
            conversationIdentifiers: [],
            service: "iMessage",
            contentKinds: [.attachment],
            associatedMessageGUID: nil,
            attachmentCount: 1,
            attachmentMIMETypes: ["image/jpeg"]
        )

        let loaded = try coordinator.loadAttachments(for: event)

        XCTAssertEqual(loaded.map(\.data), [Data("synthetic-photo".utf8)])
    }
}
