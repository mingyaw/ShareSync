import Darwin
import Foundation
import Network

struct MacPairingOffer: Codable, Equatable {
    let version: Int
    let type: String
    let deviceId: String
    let deviceName: String
    let platform: String
    let callbackURL: String
    let pairingChallenge: String
    let expiresAt: Date
}

enum MacPairingListenerError: Error {
    case localAddressUnavailable
    case listenerFailed
    case invalidRequest
}

final class MacPairingListener {
    typealias PairingHandler = @Sendable (Data) -> Void

    private let queue = DispatchQueue(label: "com.sharesync.mac.pairing-listener")
    private var listener: NWListener?
    private var challenge = ""
    private var expiresAt = Date.distantPast
    private var onPairing: PairingHandler?

    func start(targetDeviceId: String, onPairing: @escaping PairingHandler) async throws -> MacPairingOffer {
        stop()
        guard let address = Self.firstPrivateIPv4Address() else {
            throw MacPairingListenerError.localAddressUnavailable
        }

        let listener = try NWListener(using: .tcp, on: .any)
        let challenge = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        self.listener = listener
        self.challenge = challenge
        self.onPairing = onPairing
        listener.newConnectionHandler = { [weak self] connection in
            self?.receiveRequest(on: connection)
        }

        let port = try await withCheckedThrowingContinuation { continuation in
            let resumeState = ListenerResumeState()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !resumeState.resumed, let port = listener.port else { return }
                    resumeState.resumed = true
                    continuation.resume(returning: port.rawValue)
                case .failed:
                    guard !resumeState.resumed else { return }
                    resumeState.resumed = true
                    continuation.resume(throwing: MacPairingListenerError.listenerFailed)
                case .cancelled:
                    guard !resumeState.resumed else { return }
                    resumeState.resumed = true
                    continuation.resume(throwing: CancellationError())
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }

        let expiration = Date().addingTimeInterval(180)
        expiresAt = expiration
        return MacPairingOffer(
            version: 1,
            type: "sharesync_mac_pairing",
            deviceId: targetDeviceId,
            deviceName: Host.current().localizedName ?? "Mac",
            platform: "macos",
            callbackURL: "http://\(address):\(port)/v1/pairing/complete",
            pairingChallenge: challenge,
            expiresAt: expiration
        )
    }

    func stop() {
        listener?.cancel()
        listener = nil
        challenge = ""
        expiresAt = .distantPast
        onPairing = nil
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.start(queue: queue)
        receiveMore(on: connection, buffer: Data())
    }

    private func receiveMore(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var updated = buffer
            if let data { updated.append(data) }

            if let request = self.completeRequest(from: updated) {
                self.handle(request: request, on: connection)
                return
            }

            if isComplete || error != nil || updated.count >= 65_536 {
                self.respond(status: 400, on: connection)
                return
            }
            self.receiveMore(on: connection, buffer: updated)
        }
    }

    private func completeRequest(from data: Data) -> (headers: [String: String], body: Data)? {
        let separator = Data("\r\n\r\n".utf8)
        guard let headerRange = data.range(of: separator),
              let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else {
            return nil
        }
        let lines = headerText.components(separatedBy: "\r\n")
        guard lines.first == "POST /v1/pairing/complete HTTP/1.1" else { return nil }
        let headerPairs = lines.dropFirst().compactMap { line -> (String, String)? in
            guard let index = line.firstIndex(of: ":") else { return nil }
            let name = line[..<index].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: index)...].trimmingCharacters(in: .whitespaces)
            return (name, value)
        }
        let headers = headerPairs.reduce(into: [String: String]()) { result, pair in
            if result[pair.0] == nil { result[pair.0] = pair.1 }
        }
        guard let lengthText = headers["content-length"],
              let length = Int(lengthText),
              length > 0,
              length <= 60_000 else { return nil }
        let bodyStart = headerRange.upperBound
        guard data.count >= bodyStart + length else { return nil }
        return (headers, data.subdata(in: bodyStart..<(bodyStart + length)))
    }

    private func handle(request: (headers: [String: String], body: Data), on connection: NWConnection) {
        guard Date() < expiresAt,
              request.headers["x-sharesync-pairing-challenge"] == challenge,
              (try? PairingPayloadParser().parse(request.body, now: .distantPast)) != nil else {
            respond(status: 401, on: connection)
            return
        }
        let handler = onPairing
        respond(status: 202, on: connection)
        handler?(request.body)
        stop()
    }

    private func respond(status: Int, on connection: NWConnection) {
        let reason = status == 202 ? "Accepted" : status == 401 ? "Unauthorized" : "Bad Request"
        let body = status == 202 ? "{\"status\":\"accepted\"}" : "{\"status\":\"rejected\"}"
        let response = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func firstPrivateIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = current {
            defer { current = interface.pointee.ifa_next }
            guard let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET),
                  (interface.pointee.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                let value = String(cString: host)
                let octets = value.split(separator: ".").compactMap { Int($0) }
                let isPrivate = octets.count == 4 && (
                    octets[0] == 10 ||
                    (octets[0] == 192 && octets[1] == 168) ||
                    (octets[0] == 172 && (16...31).contains(octets[1]))
                )
                if isPrivate {
                    return value
                }
            }
        }
        return nil
    }
}

private final class ListenerResumeState: @unchecked Sendable {
    var resumed = false
}
