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
}
