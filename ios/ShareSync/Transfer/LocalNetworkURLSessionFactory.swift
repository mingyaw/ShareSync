import Foundation
import Security

enum LocalNetworkURLSessionFactory {
    static func shortRequestSession(transportSecurity: PairingTransportSecurity? = nil) -> URLSession {
        URLSession(
            configuration: shortRequestConfiguration(),
            delegate: urlSessionDelegate(for: transportSecurity),
            delegateQueue: nil
        )
    }

    static func mediaTransferSession(transportSecurity: PairingTransportSecurity? = nil) -> URLSession {
        URLSession(
            configuration: mediaTransferConfiguration(),
            delegate: urlSessionDelegate(for: transportSecurity),
            delegateQueue: nil
        )
    }

    static func urlSessionDelegate(for transportSecurity: PairingTransportSecurity?) -> URLSessionDelegate? {
        guard transportSecurity?.mode == .qrPinnedHTTPS else {
            return nil
        }
        return CertificatePinningURLSessionDelegate(transportSecurity: transportSecurity)
    }

    static func shortRequestConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return configuration
    }

    static func mediaTransferConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 600
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return configuration
    }
}

final class CertificatePinningURLSessionDelegate: NSObject, URLSessionDelegate {
    private let transportSecurity: PairingTransportSecurity?
    private let validator: CertificateFingerprintValidator

    init(
        transportSecurity: PairingTransportSecurity?,
        validator: CertificateFingerprintValidator = CertificateFingerprintValidator()
    ) {
        self.transportSecurity = transportSecurity
        self.validator = validator
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let certificateDER = Self.firstCertificateDER(from: serverTrust) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        switch validator.validate(certificateDER: certificateDER, transportSecurity: transportSecurity) {
        case .trusted:
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        case .notPinned:
            completionHandler(.performDefaultHandling, nil)
        case .mismatch, .invalidPinnedFingerprint, .unsupportedEncoding:
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private static func firstCertificateDER(from trust: SecTrust) -> Data? {
        let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate]
        guard let certificate = certificates?.first else {
            return nil
        }
        return SecCertificateCopyData(certificate) as Data
    }
}
