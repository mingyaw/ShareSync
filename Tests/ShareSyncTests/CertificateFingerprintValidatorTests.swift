import Foundation
import XCTest
@testable import ShareSync

final class CertificateFingerprintValidatorTests: XCTestCase {
    func testValidatesMatchingQRCodePinnedFingerprint() {
        let result = CertificateFingerprintValidator().validate(
            certificateDER: Data("local-certificate".utf8),
            transportSecurity: pinnedTransportSecurity(
                fingerprint: "c802166a63b41bd294927f901c46a8abbebf8fab203b49ed2edfa90389bc76cf"
            )
        )

        XCTAssertEqual(result, .trusted)
    }

    func testReportsPinnedFingerprintMismatchWithoutDowngrade() {
        let result = CertificateFingerprintValidator().validate(
            certificateDER: Data("different-certificate".utf8),
            transportSecurity: pinnedTransportSecurity(
                fingerprint: "c802166a63b41bd294927f901c46a8abbebf8fab203b49ed2edfa90389bc76cf"
            )
        )

        XCTAssertEqual(
            result,
            .mismatch(
                expected: "c802166a63b41bd294927f901c46a8abbebf8fab203b49ed2edfa90389bc76cf",
                actual: CertificateFingerprintValidator.sha256Hex(Data("different-certificate".utf8))
            )
        )
    }

    func testMissingOrSignedHTTPTransportSecurityIsNotPinned() {
        XCTAssertEqual(
            CertificateFingerprintValidator().validate(
                certificateDER: Data("local-certificate".utf8),
                transportSecurity: nil
            ),
            .notPinned
        )
        XCTAssertEqual(
            CertificateFingerprintValidator().validate(
                certificateDER: Data("local-certificate".utf8),
                transportSecurity: PairingTransportSecurity(
                    mode: .signedHTTP,
                    certificateFingerprintSha256: "",
                    certificateFingerprintEncoding: "hex",
                    certificateNotBefore: nil,
                    certificateNotAfter: nil
                )
            ),
            .notPinned
        )
    }

    func testRejectsUnsupportedFingerprintEncoding() {
        let result = CertificateFingerprintValidator().validate(
            certificateDER: Data("local-certificate".utf8),
            transportSecurity: pinnedTransportSecurity(
                fingerprint: "c802166a63b41bd294927f901c46a8abbebf8fab203b49ed2edfa90389bc76cf",
                encoding: "base64"
            )
        )

        XCTAssertEqual(result, .unsupportedEncoding("base64"))
    }

    func testRejectsMalformedPinnedFingerprint() {
        let result = CertificateFingerprintValidator().validate(
            certificateDER: Data("local-certificate".utf8),
            transportSecurity: pinnedTransportSecurity(fingerprint: "not-a-sha256")
        )

        XCTAssertEqual(result, .invalidPinnedFingerprint("not-a-sha256"))
    }

    private func pinnedTransportSecurity(
        fingerprint: String,
        encoding: String = "hex"
    ) -> PairingTransportSecurity {
        PairingTransportSecurity(
            mode: .qrPinnedHTTPS,
            certificateFingerprintSha256: fingerprint,
            certificateFingerprintEncoding: encoding,
            certificateNotBefore: nil,
            certificateNotAfter: nil
        )
    }
}
