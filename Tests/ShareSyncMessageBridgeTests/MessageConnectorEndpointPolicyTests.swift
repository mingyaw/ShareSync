import XCTest
@testable import ShareSyncMessageBridge

final class MessageConnectorEndpointPolicyTests: XCTestCase {
    private let policy = MessageConnectorEndpointPolicy(
        allowedHosts: ["hooks.example.com"]
    )

    func testAllowsExactHTTPSHostOnDefaultPort() throws {
        try policy.validate(XCTUnwrap(URL(string: "https://hooks.example.com/v1/messages")))
    }

    func testRejectsPlainHTTPAndEmbeddedCredentials() throws {
        XCTAssertThrowsError(try policy.validate(
            XCTUnwrap(URL(string: "http://hooks.example.com/v1/messages"))
        )) { error in
            XCTAssertEqual(error as? MessageConnectorEndpointRejection, .insecureScheme)
        }
        XCTAssertThrowsError(try policy.validate(
            XCTUnwrap(URL(string: "https://token@hooks.example.com/v1/messages"))
        )) { error in
            XCTAssertEqual(error as? MessageConnectorEndpointRejection, .credentialsInURL)
        }
    }

    func testRejectsSubdomainLookalikeAndUnexpectedPort() throws {
        XCTAssertThrowsError(try policy.validate(
            XCTUnwrap(URL(string: "https://hooks.example.com.attacker.test/v1/messages"))
        )) { error in
            XCTAssertEqual(error as? MessageConnectorEndpointRejection, .hostNotAllowed)
        }
        XCTAssertThrowsError(try policy.validate(
            XCTUnwrap(URL(string: "https://hooks.example.com:8443/v1/messages"))
        )) { error in
            XCTAssertEqual(error as? MessageConnectorEndpointRejection, .portNotAllowed)
        }
    }

    func testRedirectMustRemainInsideAllowlist() throws {
        XCTAssertThrowsError(try policy.validateRedirect(
            from: XCTUnwrap(URL(string: "https://hooks.example.com/start")),
            to: XCTUnwrap(URL(string: "https://other.example.com/final"))
        )) { error in
            XCTAssertEqual(error as? MessageConnectorEndpointRejection, .hostNotAllowed)
        }
    }

    func testFragmentIsRejectedToKeepCanonicalDestinationStable() throws {
        XCTAssertThrowsError(try policy.validate(
            XCTUnwrap(URL(string: "https://hooks.example.com/send#token"))
        )) { error in
            XCTAssertEqual(error as? MessageConnectorEndpointRejection, .fragmentNotAllowed)
        }
    }
}
