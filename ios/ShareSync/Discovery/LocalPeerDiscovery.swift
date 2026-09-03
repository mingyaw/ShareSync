import Foundation

@MainActor
protocol LocalPeerDiscovery {
    func discoverEndpoint(matchingDeviceId deviceId: String, timeout: TimeInterval) async -> PairedDeviceEndpoint?
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
