import Foundation

enum PairingPayloadParserError: Error {
    case invalidType
    case expired
}

struct PairingPayloadParser {
    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func parse(_ data: Data, now: Date = Date()) throws -> PairingPayload {
        let payload = try decoder.decode(PairingPayload.self, from: data)

        guard payload.version == 1,
              payload.type == "sharesync_pairing",
              payload.platform == "android"
        else {
            throw PairingPayloadParserError.invalidType
        }

        guard payload.expiresAt > now else {
            throw PairingPayloadParserError.expired
        }

        return payload
    }
}

