import XCTest
@testable import ShareSync

final class LocalNetworkURLSessionFactoryTests: XCTestCase {
    func testShortRequestConfigurationUsesFastLocalTimeouts() {
        let configuration = LocalNetworkURLSessionFactory.shortRequestConfiguration()

        XCTAssertEqual(configuration.timeoutIntervalForRequest, 8)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 20)
        XCTAssertTrue(configuration.waitsForConnectivity)
        XCTAssertTrue(configuration.allowsExpensiveNetworkAccess)
        XCTAssertTrue(configuration.allowsConstrainedNetworkAccess)
    }

    func testMediaTransferConfigurationAllowsLongerPhotoDownloads() {
        let configuration = LocalNetworkURLSessionFactory.mediaTransferConfiguration()

        XCTAssertEqual(configuration.timeoutIntervalForRequest, 20)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 600)
        XCTAssertTrue(configuration.waitsForConnectivity)
        XCTAssertTrue(configuration.allowsExpensiveNetworkAccess)
        XCTAssertTrue(configuration.allowsConstrainedNetworkAccess)
    }

    func testCertificatePinningDelegateIsOnlyUsedForQRCodePinnedHTTPS() {
        XCTAssertNil(LocalNetworkURLSessionFactory.urlSessionDelegate(for: nil))
        XCTAssertNil(
            LocalNetworkURLSessionFactory.urlSessionDelegate(
                for: PairingTransportSecurity(
                    mode: .signedHTTP,
                    certificateFingerprintSha256: "",
                    certificateFingerprintEncoding: "hex",
                    certificateNotBefore: nil,
                    certificateNotAfter: nil
                )
            )
        )
        XCTAssertTrue(
            LocalNetworkURLSessionFactory.urlSessionDelegate(
                for: PairingTransportSecurity(
                    mode: .qrPinnedHTTPS,
                    certificateFingerprintSha256: String(repeating: "a", count: 64),
                    certificateFingerprintEncoding: "hex",
                    certificateNotBefore: nil,
                    certificateNotAfter: nil
                )
            ) is CertificatePinningURLSessionDelegate
        )
    }
}
