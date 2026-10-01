import XCTest
@testable import ShareSyncMessageBridge

final class MessageAttachmentConsentTests: XCTestCase {
    func testConsentIsDisabledByDefault() {
        XCTAssertFalse(MessageAttachmentConsent().allowsUploads)
    }

    func testCurrentExplicitAcceptanceAllowsUploads() {
        let consent = MessageAttachmentConsent.currentAcceptance

        XCTAssertTrue(consent.allowsUploads)
        XCTAssertEqual(consent.acceptedVersion, MessageAttachmentConsent.currentVersion)
    }

    func testMissingOrStaleConsentVersionFailsClosed() {
        XCTAssertFalse(
            MessageAttachmentConsent(isEnabled: true, acceptedVersion: nil).allowsUploads
        )
        XCTAssertFalse(
            MessageAttachmentConsent(
                isEnabled: true,
                acceptedVersion: MessageAttachmentConsent.currentVersion - 1
            ).allowsUploads
        )
    }
}
