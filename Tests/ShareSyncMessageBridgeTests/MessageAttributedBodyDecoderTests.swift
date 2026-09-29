import Foundation
import XCTest
@testable import ShareSyncMessageBridge

final class MessageAttributedBodyDecoderTests: XCTestCase {
    func testSecureKeyedAttributedStringDecodesToPlainText() throws {
        let source = NSAttributedString(string: "Unicode 測試 👋")
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: source,
            requiringSecureCoding: true
        )

        XCTAssertEqual(
            SecureKeyedAttributedBodyDecoder().decodeText(from: data),
            "Unicode 測試 👋"
        )
    }

    func testUnknownArchiveFailsClosed() {
        XCTAssertNil(SecureKeyedAttributedBodyDecoder().decodeText(from: Data([0x01, 0x02])))
    }

    func testNormalizerUsesDecodedBodyWithoutExposingRawArchive() throws {
        let source = NSAttributedString(string: "decoded")
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: source,
            requiringSecureCoding: true
        )
        let event = MessageEvent(
            rowID: 1,
            guid: "guid",
            body: nil,
            rawDate: 1,
            isFromMe: false,
            service: "iMessage",
            hasAttachments: false,
            associatedMessageType: 0,
            associatedMessageGUID: nil,
            hasAttributedBody: true,
            attributedBodyData: data,
            senderIdentifier: "sender",
            conversationIdentifiers: [],
            attachmentCount: 0,
            attachmentMIMETypes: []
        )

        let normalized = MessageEventNormalizer().normalize(event)

        XCTAssertEqual(normalized.body, "decoded")
        XCTAssertTrue(normalized.contentKinds.contains(.richText))
    }
}
