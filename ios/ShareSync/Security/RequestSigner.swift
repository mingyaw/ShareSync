import CryptoKit
import Foundation

struct RequestSigningContext: Equatable {
    let deviceId: String
    let sessionId: String
    let secret: String
}

struct RequestSigner {
    var timestampProvider: () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) }
    var nonceProvider: () -> String = { UUID().uuidString.replacingOccurrences(of: "-", with: "") }

    func sign(
        request: inout URLRequest,
        context: RequestSigningContext,
        body: Data = Data()
    ) {
        let timestamp = "\(timestampProvider())"
        let nonce = nonceProvider()
        let method = request.httpMethod ?? "GET"
        let path = request.url?.path(percentEncoded: true) ?? "/"
        let signature = Self.signature(
            secret: context.secret,
            method: method,
            path: path,
            timestamp: timestamp,
            nonce: nonce,
            body: body
        )

        request.setValue("1", forHTTPHeaderField: Self.versionHeader)
        request.setValue(context.deviceId, forHTTPHeaderField: Self.deviceIdHeader)
        request.setValue(context.sessionId, forHTTPHeaderField: Self.sessionIdHeader)
        request.setValue(timestamp, forHTTPHeaderField: Self.timestampHeader)
        request.setValue(nonce, forHTTPHeaderField: Self.nonceHeader)
        request.setValue(signature, forHTTPHeaderField: Self.signatureHeader)
    }

    static func signature(
        secret: String,
        method: String,
        path: String,
        timestamp: String,
        nonce: String,
        body: Data
    ) -> String {
        let canonicalPayload = [
            method.uppercased(),
            path,
            timestamp,
            nonce,
            sha256Hex(body),
        ].joined(separator: "\n")
        let key = SymmetricKey(data: Data(secret.utf8))
        let authenticationCode = HMAC<SHA256>.authenticationCode(
            for: Data(canonicalPayload.utf8),
            using: key
        )
        return Data(authenticationCode).base64EncodedString()
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static let versionHeader = "X-ShareSync-Version"
    static let deviceIdHeader = "X-Device-Id"
    static let sessionIdHeader = "X-Session-Id"
    static let timestampHeader = "X-Timestamp"
    static let nonceHeader = "X-Nonce"
    static let signatureHeader = "X-Signature"
}
