import XCTest
@testable import ShareSync

@MainActor
final class PairedEndpointResolverTests: XCTestCase {
    func testPairedDeviceUsesDiscoveredEndpointBeforeStoredEndpoint() async throws {
        let discovery = StubLocalPeerDiscovery(
            endpoint: PairedDeviceEndpoint(host: "192.168.1.50", port: 48291, updatedAt: Date())
        )
        let resolver = PairedEndpointResolver(discoveryTimeout: 0.1)

        let endpoint = try await resolver.endpointCandidate(
            pairedDevice: pairedDevice(),
            host: "192.168.1.10",
            port: "48291",
            discovery: discovery
        )

        XCTAssertEqual(endpoint.host, "192.168.1.50")
        XCTAssertEqual(endpoint.port, 48291)
        XCTAssertEqual(discovery.requestedDeviceId, "android-demo-device")
    }

    func testPairedDeviceFallsBackToStoredEndpointWhenDiscoveryMisses() async throws {
        let discovery = StubLocalPeerDiscovery(endpoint: nil)
        let resolver = PairedEndpointResolver(discoveryTimeout: 0.1)

        let endpoint = try await resolver.endpointCandidate(
            pairedDevice: pairedDevice(),
            host: " 192.168.1.10 ",
            port: "48291",
            discovery: discovery
        )

        XCTAssertEqual(endpoint.host, "192.168.1.10")
        XCTAssertEqual(endpoint.port, 48291)
    }

    func testMissingHostStillRequiresFreshPairingOrEndpoint() async {
        let discovery = StubLocalPeerDiscovery(endpoint: nil)
        let resolver = PairedEndpointResolver(discoveryTimeout: 0.1)

        do {
            _ = try await resolver.endpointCandidate(
                pairedDevice: nil,
                host: "",
                port: "48291",
                discovery: discovery
            )
            XCTFail("Expected missing host to throw.")
        } catch {
            XCTAssertEqual(error as? EndpointResolutionError, .missingHost)
        }
    }

    func testInvalidPortBlocksStoredEndpointFallback() async {
        let discovery = StubLocalPeerDiscovery(endpoint: nil)
        let resolver = PairedEndpointResolver(discoveryTimeout: 0.1)

        do {
            _ = try await resolver.endpointCandidate(
                pairedDevice: pairedDevice(),
                host: "192.168.1.10",
                port: "99999",
                discovery: discovery
            )
            XCTFail("Expected invalid port to throw.")
        } catch {
            XCTAssertEqual(error as? EndpointResolutionError, .invalidPort)
        }
    }

    private func pairedDevice() -> TrustedDevice {
        TrustedDevice(
            deviceId: "android-demo-device",
            deviceName: "Pixel Demo",
            platform: "android",
            publicKey: "public-key",
            pairingToken: "pairing-token-001",
            pairedAt: Date(timeIntervalSince1970: 1),
            lastSeenAt: nil,
            trustStatus: .trusted,
            transportSecurity: nil
        )
    }
}

@MainActor
private final class StubLocalPeerDiscovery: LocalPeerDiscovery {
    private let endpoint: PairedDeviceEndpoint?
    private(set) var requestedDeviceId: String?

    init(endpoint: PairedDeviceEndpoint?) {
        self.endpoint = endpoint
    }

    func discoverEndpoint(matchingDeviceId deviceId: String, timeout: TimeInterval) async -> PairedDeviceEndpoint? {
        requestedDeviceId = deviceId
        return endpoint
    }
}
