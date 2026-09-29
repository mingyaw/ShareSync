import XCTest
@testable import ShareSyncMessageBridge

final class MessageConnectorCredentialVaultTests: XCTestCase {
    func testCredentialLifecycleIsScopedByConnectorID() throws {
        let vault = InMemoryMessageConnectorCredentialVault()
        let first = Data("first-secret".utf8)
        let second = Data("second-secret".utf8)

        try vault.setCredential(first, for: "connector-a")
        try vault.setCredential(second, for: "connector-b")

        XCTAssertEqual(try vault.credential(for: "connector-a"), first)
        XCTAssertEqual(try vault.credential(for: "connector-b"), second)
        try vault.removeCredential(for: "connector-a")
        XCTAssertNil(try vault.credential(for: "connector-a"))
        XCTAssertEqual(try vault.credential(for: "connector-b"), second)
    }

    func testCredentialCanBeRotatedWithoutLeavingOldValue() throws {
        let vault = InMemoryMessageConnectorCredentialVault()
        try vault.setCredential(Data("old".utf8), for: "connector")

        try vault.setCredential(Data("new".utf8), for: "connector")

        XCTAssertEqual(try vault.credential(for: "connector"), Data("new".utf8))
    }
}
