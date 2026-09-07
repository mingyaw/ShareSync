import XCTest
@testable import ShareSync

final class PhotoSyncReadinessTests: XCTestCase {
    func testPairingIsPrimaryActionWhenNoDeviceOrEndpointExists() {
        let readiness = PhotoSyncReadiness.evaluate(
            hasPairedDevice: false,
            host: "",
            port: "48291",
            photoLibraryPermissionStatus: .notDetermined,
            isFetchingManifest: false,
            isTransferActive: false,
            hasManifest: false
        )

        XCTAssertFalse(readiness.canFetchManifest)
        XCTAssertFalse(readiness.canSyncAllPhotos)
        XCTAssertEqual(readiness.primaryAction, .pairAndroid)
        XCTAssertEqual(readiness.blockingReason, .pairingRequired)
        XCTAssertEqual(readiness.recoveryGuidance, .scanAndroidQRCode)
    }

    func testInvalidPortBlocksFetchAndSync() {
        let readiness = PhotoSyncReadiness.evaluate(
            hasPairedDevice: true,
            host: "192.168.1.10",
            port: "99999",
            photoLibraryPermissionStatus: .authorized,
            isFetchingManifest: false,
            isTransferActive: false,
            hasManifest: false
        )

        XCTAssertFalse(readiness.canFetchManifest)
        XCTAssertFalse(readiness.canSyncAllPhotos)
        XCTAssertEqual(readiness.primaryAction, .enterEndpoint)
        XCTAssertEqual(readiness.blockingReason, .invalidPort)
        XCTAssertEqual(readiness.recoveryGuidance, .reviewAndroidEndpoint)
    }

    func testDeniedPhotosBlocksSyncButAllowsManifestRefresh() {
        let readiness = PhotoSyncReadiness.evaluate(
            hasPairedDevice: true,
            host: "192.168.1.10",
            port: "48291",
            photoLibraryPermissionStatus: .denied,
            isFetchingManifest: false,
            isTransferActive: false,
            hasManifest: true
        )

        XCTAssertTrue(readiness.canFetchManifest)
        XCTAssertFalse(readiness.canSyncAllPhotos)
        XCTAssertEqual(readiness.primaryAction, .allowPhotos)
        XCTAssertEqual(readiness.blockingReason, .photosPermissionBlocked(.denied))
        XCTAssertEqual(readiness.recoveryGuidance, .allowIPhonePhotos)
    }

    func testActiveTransferBlocksNewActions() {
        let readiness = PhotoSyncReadiness.evaluate(
            hasPairedDevice: true,
            host: "192.168.1.10",
            port: "48291",
            photoLibraryPermissionStatus: .authorized,
            isFetchingManifest: false,
            isTransferActive: true,
            hasManifest: true
        )

        XCTAssertFalse(readiness.canFetchManifest)
        XCTAssertFalse(readiness.canSyncAllPhotos)
        XCTAssertEqual(readiness.primaryAction, .waitForTransfer)
        XCTAssertEqual(readiness.blockingReason, .transferActive)
        XCTAssertEqual(readiness.recoveryGuidance, .waitForActiveTransfer)
    }

    func testReadyStateFetchesBeforeManifestAndSyncsAfterManifest() {
        let readyToFetch = PhotoSyncReadiness.evaluate(
            hasPairedDevice: true,
            host: "192.168.1.10",
            port: "48291",
            photoLibraryPermissionStatus: .notDetermined,
            isFetchingManifest: false,
            isTransferActive: false,
            hasManifest: false
        )
        let readyToSync = PhotoSyncReadiness.evaluate(
            hasPairedDevice: true,
            host: "192.168.1.10",
            port: "48291",
            photoLibraryPermissionStatus: .limited,
            isFetchingManifest: false,
            isTransferActive: false,
            hasManifest: true
        )

        XCTAssertTrue(readyToFetch.canFetchManifest)
        XCTAssertTrue(readyToFetch.canSyncAllPhotos)
        XCTAssertEqual(readyToFetch.primaryAction, .fetchManifest)
        XCTAssertNil(readyToFetch.blockingReason)
        XCTAssertEqual(readyToFetch.recoveryGuidance, .fetchLatestManifest)
        XCTAssertTrue(readyToSync.canFetchManifest)
        XCTAssertTrue(readyToSync.canSyncAllPhotos)
        XCTAssertEqual(readyToSync.primaryAction, .syncAllPhotos)
        XCTAssertNil(readyToSync.blockingReason)
        XCTAssertEqual(readyToSync.recoveryGuidance, .syncRemainingPhotos)
    }
}
