import XCTest
@testable import ShareSync

final class PhotoLibraryPermissionStatusTests: XCTestCase {
    func testAllowedPermissionStatusesCanImport() {
        XCTAssertTrue(PhotoLibraryPermissionStatus.authorized.allowsImport)
        XCTAssertTrue(PhotoLibraryPermissionStatus.limited.allowsImport)
    }

    func testBlockedPermissionStatusesCannotImport() {
        XCTAssertFalse(PhotoLibraryPermissionStatus.denied.allowsImport)
        XCTAssertFalse(PhotoLibraryPermissionStatus.restricted.allowsImport)
        XCTAssertFalse(PhotoLibraryPermissionStatus.notDetermined.allowsImport)
        XCTAssertFalse(PhotoLibraryPermissionStatus.unknown.allowsImport)
    }
}
