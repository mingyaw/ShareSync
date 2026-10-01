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

    func testUserDefaultsStorePersistsCurrentAcceptance() {
        let fixture = makeStore()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

        fixture.store.save(.currentAcceptance)

        XCTAssertEqual(fixture.store.load(), .currentAcceptance)
    }

    func testUserDefaultsStoreRejectsStaleConsentAndClearsVersion() {
        let fixture = makeStore()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.defaults.set(true, forKey: "attachment-enabled")
        fixture.defaults.set(
            MessageAttachmentConsent.currentVersion - 1,
            forKey: "attachment-version"
        )

        let staleConsent = fixture.store.load()
        fixture.store.save(staleConsent)

        XCTAssertFalse(staleConsent.allowsUploads)
        XCTAssertFalse(fixture.defaults.bool(forKey: "attachment-enabled"))
        XCTAssertNil(fixture.defaults.object(forKey: "attachment-version"))
    }

    func testUserDefaultsStoreClearRevokesConsent() {
        let fixture = makeStore()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.store.save(.currentAcceptance)

        fixture.store.clear()

        XCTAssertEqual(fixture.store.load(), MessageAttachmentConsent())
    }

    private func makeStore() -> (
        store: UserDefaultsMessageAttachmentConsentStore,
        defaults: UserDefaults,
        suiteName: String
    ) {
        let suiteName = "MessageAttachmentConsentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (
            UserDefaultsMessageAttachmentConsentStore(
                defaults: defaults,
                enabledKey: "attachment-enabled",
                versionKey: "attachment-version"
            ),
            defaults,
            suiteName
        )
    }
}
