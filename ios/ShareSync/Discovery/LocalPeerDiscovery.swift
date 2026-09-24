import Foundation

@MainActor
protocol LocalPeerDiscovery {
    func discoverEndpoint(matchingDeviceId deviceId: String, timeout: TimeInterval) async -> PairedDeviceEndpoint?
}

struct NearbyAndroidDevice: Identifiable, Equatable {
    let deviceId: String
    let deviceName: String
    let endpoint: PairedDeviceEndpoint

    var id: String { deviceId }
}

@MainActor
protocol NearbyPeerDiscovery {
    func discoverPeers(timeout: TimeInterval) async -> [NearbyAndroidDevice]
    func stop()
}

struct NearbyAndroidDeviceResolver {
    func resolve(
        serviceName: String,
        hostName: String?,
        port: Int,
        attributes: [String: Data],
        now: Date = Date()
    ) -> NearbyAndroidDevice? {
        guard let hostName,
              !hostName.isEmpty,
              port > 0,
              let platformData = attributes["platform"],
              String(data: platformData, encoding: .utf8) == "android",
              let deviceIdData = attributes["deviceId"],
              let deviceId = String(data: deviceIdData, encoding: .utf8),
              !deviceId.isEmpty
        else {
            return nil
        }

        let advertisedName = attributes["deviceName"]
            .flatMap { String(data: $0, encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = serviceName
            .replacingOccurrences(of: "ShareSync ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let deviceName = advertisedName.flatMap { $0.isEmpty ? nil : $0 }
            ?? (fallbackName.isEmpty ? "Android" : fallbackName)

        return NearbyAndroidDevice(
            deviceId: deviceId,
            deviceName: deviceName,
            endpoint: PairedDeviceEndpoint(host: hostName, port: port, updatedAt: now)
        )
    }
}

enum EndpointResolutionError: Error {
    case missingHost
    case invalidPort
    case unexpectedPeer
}

struct PairedEndpointResolver {
    let discoveryTimeout: TimeInterval

    init(discoveryTimeout: TimeInterval = 2.5) {
        self.discoveryTimeout = discoveryTimeout
    }

    @MainActor
    func endpointCandidate(
        pairedDevice: TrustedDevice?,
        host: String,
        port: String,
        discovery: LocalPeerDiscovery
    ) async throws -> PairedDeviceEndpoint {
        if let pairedDevice,
           let discoveredEndpoint = await discovery.discoverEndpoint(
            matchingDeviceId: pairedDevice.deviceId,
            timeout: discoveryTimeout
           ) {
            return discoveredEndpoint
        }

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            throw EndpointResolutionError.missingHost
        }

        guard let portNumber = Int(port), (1...65535).contains(portNumber) else {
            throw EndpointResolutionError.invalidPort
        }

        return PairedDeviceEndpoint(
            host: trimmedHost,
            port: portNumber,
            updatedAt: Date()
        )
    }
}

@MainActor
final class BonjourLocalPeerDiscovery: NSObject, LocalPeerDiscovery {
    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    private var continuation: CheckedContinuation<PairedDeviceEndpoint?, Never>?
    private var targetDeviceId: String?
    private var timeoutTask: Task<Void, Never>?

    func discoverEndpoint(matchingDeviceId deviceId: String, timeout: TimeInterval = 3) async -> PairedDeviceEndpoint? {
        await withCheckedContinuation { continuation in
            self.stopBrowsing(resumeWith: nil)
            self.targetDeviceId = deviceId
            self.continuation = continuation
            let browser = NetServiceBrowser()
            browser.delegate = self
            self.browser = browser
            browser.searchForServices(ofType: "_sharesync._tcp.", inDomain: "local.")
            self.timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await MainActor.run {
                    self?.stopBrowsing(resumeWith: nil)
                }
            }
        }
    }

    private func stopBrowsing(resumeWith endpoint: PairedDeviceEndpoint?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        services.forEach { service in
            service.stop()
            service.delegate = nil
        }
        services.removeAll()
        browser?.stop()
        browser?.delegate = nil
        browser = nil
        targetDeviceId = nil
        guard let continuation else {
            return
        }
        self.continuation = nil
        continuation.resume(returning: endpoint)
    }
}

extension BonjourLocalPeerDiscovery: @preconcurrency NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        services.append(service)
        service.resolve(withTimeout: 2)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Task { @MainActor in
            stopBrowsing(resumeWith: nil)
        }
    }
}

extension BonjourLocalPeerDiscovery: @preconcurrency NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let endpoint = endpointIfServiceMatches(sender) else {
            return
        }
        Task { @MainActor in
            stopBrowsing(resumeWith: endpoint)
        }
    }

    private func endpointIfServiceMatches(_ service: NetService) -> PairedDeviceEndpoint? {
        guard let targetDeviceId,
              let data = service.txtRecordData(),
              let attributes = NetService.dictionary(fromTXTRecord: data)["deviceId"],
              String(data: attributes, encoding: .utf8) == targetDeviceId,
              let hostName = service.hostName,
              service.port > 0
        else {
            return nil
        }

        return PairedDeviceEndpoint(
            host: hostName,
            port: service.port,
            updatedAt: Date()
        )
    }
}

@MainActor
final class BonjourNearbyPeerDiscovery: NSObject, NearbyPeerDiscovery {
    private let resolver: NearbyAndroidDeviceResolver
    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    private var discovered: [String: NearbyAndroidDevice] = [:]
    private var continuation: CheckedContinuation<[NearbyAndroidDevice], Never>?
    private var timeoutTask: Task<Void, Never>?

    init(resolver: NearbyAndroidDeviceResolver = NearbyAndroidDeviceResolver()) {
        self.resolver = resolver
    }

    func discoverPeers(timeout: TimeInterval = 3) async -> [NearbyAndroidDevice] {
        await withCheckedContinuation { continuation in
            finish()
            self.continuation = continuation
            let browser = NetServiceBrowser()
            browser.delegate = self
            self.browser = browser
            browser.searchForServices(ofType: "_sharesync._tcp.", inDomain: "local.")
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.finish() }
            }
        }
    }

    func stop() {
        finish()
    }

    private func finish() {
        timeoutTask?.cancel()
        timeoutTask = nil
        services.forEach { service in
            service.stop()
            service.delegate = nil
        }
        services.removeAll()
        browser?.stop()
        browser?.delegate = nil
        browser = nil
        let result = discovered.values.sorted {
            $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending
        }
        discovered.removeAll()
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: result)
    }
}

extension BonjourNearbyPeerDiscovery: @preconcurrency NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        services.append(service)
        service.resolve(withTimeout: 2)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Task { @MainActor in finish() }
    }
}

extension BonjourNearbyPeerDiscovery: @preconcurrency NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let data = sender.txtRecordData(),
              let device = resolver.resolve(
                serviceName: sender.name,
                hostName: sender.hostName,
                port: sender.port,
                attributes: NetService.dictionary(fromTXTRecord: data)
              )
        else {
            return
        }
        discovered[device.deviceId] = device
    }
}
