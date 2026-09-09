import CryptoKit
import Foundation

enum CertificateFingerprintValidationResult: Equatable {
    case notPinned
    case trusted
    case mismatch(expected: String, actual: String)
    case invalidPinnedFingerprint(String)
    case unsupportedEncoding(String)
}

struct CertificateFingerprintValidator {
    func validate(
        certificateDER: Data,
        transportSecurity: PairingTransportSecurity?
    ) -> CertificateFingerprintValidationResult {
        guard let transportSecurity else {
            return .notPinned
        }

        guard transportSecurity.mode == .qrPinnedHTTPS else {
            return .notPinned
        }

        let encoding = transportSecurity.certificateFingerprintEncoding.lowercased()
        guard encoding == "hex" else {
            return .unsupportedEncoding(transportSecurity.certificateFingerprintEncoding)
        }

        let expected = transportSecurity.certificateFingerprintSha256.lowercased()
        guard Self.isValidSHA256Hex(expected) else {
            return .invalidPinnedFingerprint(transportSecurity.certificateFingerprintSha256)
        }

        let actual = Self.sha256Hex(certificateDER)
        guard expected == actual else {
            return .mismatch(expected: expected, actual: actual)
        }

        return .trusted
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func isValidSHA256Hex(_ value: String) -> Bool {
        value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    }
}
