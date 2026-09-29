import XCTest
@testable import ShareSyncMessageBridge

final class TelegramBotConnectorTests: XCTestCase {
    func testConfigurationRejectsUnsafeTokenAndInvalidChatID() {
        XCTAssertThrowsError(try TelegramBotConfiguration(token: "123/path:secret", chatID: "42"))
        XCTAssertThrowsError(try TelegramBotConfiguration(token: "123:abcdefghijklmnopqrst", chatID: "not-a-chat"))
    }

    func testConnectorPostsJSONOnlyToTelegramHTTPSHost() throws {
        let transport = RecordingTelegramTransport(response: successResponse())
        let configuration = try TelegramBotConfiguration(
            token: "123456:abcdefghijklmnopqrstuvwxyz_ABC",
            chatID: "-1001234567890"
        )
        let connector = TelegramBotConnector(configuration: configuration, transport: transport)
        let envelope = MessageConnectorEnvelope(
            deliveryKey: "opaque-key",
            body: "hello",
            timestamp: Date(timeIntervalSince1970: 1_000),
            senderLabel: "Work",
            attachmentCount: 0,
            attachmentMIMETypes: [],
            containsRichText: false
        )

        XCTAssertEqual(try connector.deliver(envelope), .delivered)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.scheme, "https")
        XCTAssertEqual(request.url?.host, "api.telegram.org")
        XCTAssertEqual(request.url?.lastPathComponent, "sendMessage")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["chat_id"] as? String, "-1001234567890")
        XCTAssertTrue((json["text"] as? String)?.contains("hello") == true)
        XCTAssertFalse(String(data: body, encoding: .utf8)?.contains("opaque-key") == true)
    }

    func testConnectorMapsTelegramRateLimit() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "ok": false,
            "error_code": 429,
            "description": "Too Many Requests",
            "parameters": ["retry_after": 12],
        ])
        let transport = RecordingTelegramTransport(
            response: TelegramBotHTTPResponse(statusCode: 429, data: data)
        )
        let configuration = try TelegramBotConfiguration(
            token: "123456:abcdefghijklmnopqrstuvwxyz_ABC",
            chatID: "42"
        )

        XCTAssertThrowsError(
            try TelegramBotConnector(configuration: configuration, transport: transport).verifyDelivery()
        ) { error in
            XCTAssertEqual(error as? TelegramBotConnectorError, .rateLimited(retryAfter: 12))
        }
    }

    func testSuccessfulDeliveryStoresLocalReplyRouteFromTelegramMessageID() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "ok": true,
            "result": ["message_id": 321],
        ])
        let transport = RecordingTelegramTransport(
            response: TelegramBotHTTPResponse(statusCode: 200, data: data)
        )
        let routes = RecordingRouteStore()
        let configuration = try TelegramBotConfiguration(
            token: "123456:abcdefghijklmnopqrstuvwxyz_ABC",
            chatID: "42"
        )
        let connector = TelegramBotConnector(
            configuration: configuration,
            transport: transport,
            replyRouteStore: routes
        )
        let envelope = MessageConnectorEnvelope(
            deliveryKey: "opaque",
            body: "hello",
            timestamp: Date(timeIntervalSince1970: 1_000),
            senderLabel: "+886912345678",
            attachmentCount: 0,
            attachmentMIMETypes: [],
            containsRichText: false
        )

        _ = try connector.deliver(envelope)

        XCTAssertEqual(routes.routes.first?.telegramMessageID, 321)
        XCTAssertEqual(routes.routes.first?.recipientHandle, "+886912345678")
        XCTAssertEqual(routes.routes.first?.telegramChatID, "42")
    }

    func testFormatterRespectsTelegramTextLimitAndSummarizesAttachments() {
        let formatter = TelegramBotMessageFormatter(maximumLength: 128)
        let envelope = MessageConnectorEnvelope(
            deliveryKey: "key",
            body: String(repeating: "a", count: 500),
            timestamp: Date(timeIntervalSince1970: 1_000),
            senderLabel: "Work",
            attachmentCount: 2,
            attachmentMIMETypes: ["image/jpeg"],
            containsRichText: true
        )

        let output = formatter.message(for: envelope)

        XCTAssertEqual(output.count, 128)
        XCTAssertTrue(output.hasSuffix("\n…"))
    }

    private func successResponse() -> TelegramBotHTTPResponse {
        TelegramBotHTTPResponse(
            statusCode: 200,
            data: Data(#"{"ok":true,"result":{"message_id":123}}"#.utf8)
        )
    }
}

private final class RecordingRouteStore: TelegramReplyRouteStoring {
    private(set) var routes: [TelegramReplyRoute] = []
    func save(_ route: TelegramReplyRoute) throws { routes.append(route) }
    func route(chatID: String, messageID: Int64) throws -> TelegramReplyRoute? { nil }
    func clear() throws { routes.removeAll() }
}

private final class RecordingTelegramTransport: TelegramBotTransport {
    let response: TelegramBotHTTPResponse
    private(set) var requests: [URLRequest] = []

    init(response: TelegramBotHTTPResponse) {
        self.response = response
    }

    func execute(_ request: URLRequest) throws -> TelegramBotHTTPResponse {
        requests.append(request)
        return response
    }
}
