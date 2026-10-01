import Foundation

public final class TelegramBotMediaUploader {
    private struct APIResponse: Decodable {
        struct Parameters: Decodable {
            let retryAfter: Int?

            enum CodingKeys: String, CodingKey {
                case retryAfter = "retry_after"
            }
        }

        struct SentMessage: Decodable {
            let messageID: Int64

            enum CodingKeys: String, CodingKey {
                case messageID = "message_id"
            }
        }

        let ok: Bool
        let errorCode: Int?
        let description: String?
        let parameters: Parameters?
        let result: SentMessage?

        enum CodingKeys: String, CodingKey {
            case ok
            case errorCode = "error_code"
            case description
            case parameters, result
        }
    }

    private let configuration: TelegramBotConfiguration
    private let policy: MessageAttachmentUploadPolicy
    private let transport: any TelegramBotTransport
    private let boundary: String

    public init(
        configuration: TelegramBotConfiguration,
        policy: MessageAttachmentUploadPolicy,
        transport: any TelegramBotTransport = URLSessionTelegramBotTransport()
    ) {
        self.configuration = configuration
        self.policy = policy
        self.transport = transport
        self.boundary = "ShareSyncBoundary" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    init(
        configuration: TelegramBotConfiguration,
        policy: MessageAttachmentUploadPolicy,
        transport: any TelegramBotTransport,
        boundary: String
    ) {
        precondition(Self.isValidBoundary(boundary))
        self.configuration = configuration
        self.policy = policy
        self.transport = transport
        self.boundary = boundary
    }

    @discardableResult
    public func uploadPhoto(
        _ attachment: ValidatedMessageAttachment,
        data: Data
    ) throws -> Int64? {
        try policy.validateReadByteCount(data.count, for: attachment)

        let endpoint = "https://api.telegram.org/bot\(configuration.token)/sendPhoto"
        guard let url = URL(string: endpoint),
              url.scheme == "https",
              url.host == "api.telegram.org" else {
            throw TelegramBotConnectorError.invalidToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = multipartBody(attachment: attachment, data: data)

        let response = try transport.execute(request)
        guard let payload = try? JSONDecoder().decode(APIResponse.self, from: response.data) else {
            throw TelegramBotConnectorError.invalidResponse
        }
        if payload.ok, (200..<300).contains(response.statusCode) {
            return payload.result?.messageID
        }
        if response.statusCode == 429 || payload.errorCode == 429 {
            throw TelegramBotConnectorError.rateLimited(
                retryAfter: TimeInterval(payload.parameters?.retryAfter ?? 60)
            )
        }
        throw TelegramBotConnectorError.apiFailure(
            code: payload.errorCode ?? response.statusCode,
            description: payload.description ?? "Telegram request failed"
        )
    }

    private func multipartBody(
        attachment: ValidatedMessageAttachment,
        data: Data
    ) -> Data {
        let filename = attachment.mimeType == "image/png" ? "sharesync.png" : "sharesync.jpg"
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n")
        body.appendUTF8(configuration.chatID)
        body.appendUTF8("\r\n")
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8(
            "Content-Disposition: form-data; name=\"photo\"; filename=\"\(filename)\"\r\n"
        )
        body.appendUTF8("Content-Type: \(attachment.mimeType)\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        return body
    }

    private static func isValidBoundary(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 70 && value.allSatisfy {
            $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_"
        }
    }
}

extension TelegramBotMediaUploader: MessageAttachmentForwardingConnector {
    public func deliver(_ attachment: LoadedMessageAttachment) throws {
        try uploadPhoto(attachment.attachment, data: attachment.data)
    }
}

private extension Data {
    mutating func appendUTF8(_ value: String) {
        append(contentsOf: value.utf8)
    }
}
