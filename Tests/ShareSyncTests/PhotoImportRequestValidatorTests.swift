import Foundation
import XCTest
@testable import ShareSync

final class PhotoImportRequestValidatorTests: XCTestCase {
    func testValidateAcceptsMatchingFileSize() throws {
        let request = makeRequest(sourceSize: 12)
        let validator = PhotoImportRequestValidator { _ in 12 }

        XCTAssertNoThrow(try validator.validate(request))
    }

    func testValidateRejectsMismatchedFileSize() throws {
        let request = makeRequest(sourceSize: 12)
        let validator = PhotoImportRequestValidator { _ in 7 }

        XCTAssertThrowsError(try validator.validate(request)) { error in
            XCTAssertEqual(
                error as? PhotoImportRequestValidationError,
                .fileSizeMismatch(expected: 12, actual: 7)
            )
        }
    }

    private func makeRequest(sourceSize: Int64) -> PhotoImportRequest {
        PhotoImportRequest(
            sourceAssetId: "media-001",
            sourceHash: nil,
            sourceSize: sourceSize,
            localFileURL: URL(fileURLWithPath: "/tmp/media-001.jpg"),
            mediaType: .photo
        )
    }
}
