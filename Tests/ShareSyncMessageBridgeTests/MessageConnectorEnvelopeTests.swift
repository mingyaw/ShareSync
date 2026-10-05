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

    func testBuilderSeparatesDisplayAliasFromReplyRecipient() {
        let source = makeEvent(sender: "+886 (900) 000-000")

        let envelope = MessageConnectorEnvelopeBuilder(
            senderLabels: ["+886900000000": "On-call"],
            includeReplyRouting: true
        ).build(from: source)

        XCTAssertEqual(envelope.senderLabel, "On-call")
        XCTAssertEqual(envelope.replyRecipientHandle, "+886900000000")
    }

    func testUnknownSenderHasNoLabelAndAttachmentSummaryCanBeDisabled() {
        let source = makeEvent(sender: "unknown", attachmentCount: 2)

        let envelope = MessageConnectorEnvelopeBuilder(
            includeAttachmentSummary: false
        ).build(from: source)

        XCTAssertNil(envelope.senderLabel)
        XCTAssertTrue(envelope.hasAttachments)
        XCTAssertEqual(envelope.attachmentCount, 0)
        XCTAssertTrue(envelope.attachmentMIMETypes.isEmpty)
    }

    func testBuilderFindsReplyLabelAcrossPhoneFormattingDifferences() {
        let envelope = MessageConnectorEnvelopeBuilder(
            senderLabels: ["+886 900-000-000": "+886900000000"]
        ).build(from: makeEvent(sender: "+886900000000"))

        XCTAssertEqual(envelope.senderLabel, "+886900000000")
    }

    func testCanonicalizerHandlesEmailPhoneAndOpaqueIdentifiersConservatively() {
        XCTAssertEqual(MessageSenderIdentifier.canonical(" Person@Example.COM "), "person@example.com")
        XCTAssertEqual(MessageSenderIdentifier.canonical("+886 (912) 345-678"), "+886912345678")
        XCTAssertEqual(MessageSenderIdentifier.canonical("Case-Sensitive-ID"), "Case-Sensitive-ID")
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
