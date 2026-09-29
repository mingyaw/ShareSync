import XCTest
@testable import ShareSyncMessageBridge

final class MessageConnectorEnvelopeTests: XCTestCase {
    func testBuilderReplacesSenderIdentifierWithExplicitAlias() {
        let source = makeEvent(sender: "+886900000000")

        let envelope = MessageConnectorEnvelopeBuilder(
            senderLabels: ["+886900000000": "On-call"]
        ).build(from: source)

        XCTAssertEqual(envelope.senderLabel, "On-call")
        XCTAssertEqual(envelope.body, "allowed body")
        XCTAssertEqual(envelope.deliveryKey, "opaque-key")
        XCTAssertFalse(String(reflecting: envelope).contains("private-guid"))
        XCTAssertFalse(String(reflecting: envelope).contains("private-conversation"))
        XCTAssertFalse(String(reflecting: envelope).contains("+886900000000"))
    }

    func testUnknownSenderHasNoLabelAndAttachmentSummaryCanBeDisabled() {
        let source = makeEvent(sender: "unknown", attachmentCount: 2)

        let envelope = MessageConnectorEnvelopeBuilder(
            includeAttachmentSummary: false
        ).build(from: source)

        XCTAssertNil(envelope.senderLabel)
        XCTAssertEqual(envelope.attachmentCount, 0)
        XCTAssertTrue(envelope.attachmentMIMETypes.isEmpty)
    }

    private func makeEvent(sender: String, attachmentCount: Int = 0) -> NormalizedMessageEvent {
        NormalizedMessageEvent(
            deliveryKey: "opaque-key",
            sourceRowID: 42,
            sourceGUID: "private-guid",
            body: "allowed body",
            timestamp: Date(timeIntervalSince1970: 100),
            direction: .incoming,
            senderIdentifier: sender,
            conversationIdentifiers: ["private-conversation"],
            service: "iMessage",
            contentKinds: attachmentCount == 0 ? [.text] : [.text, .attachment],
            associatedMessageGUID: "private-associated-guid",
            attachmentCount: attachmentCount,
            attachmentMIMETypes: attachmentCount == 0 ? [] : ["image/jpeg"]
        )
    }
}
