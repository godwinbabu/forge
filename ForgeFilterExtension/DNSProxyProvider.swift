import Network
import NetworkExtension
import ForgeKit

final class DNSProxyProvider: NEDNSProxyProvider, @unchecked Sendable {
    private var activeRuleset: BlockRuleset?
    private var domainMatcher: DomainMatcher?

    static let sharedIPMap = IPHostnameMap()

    override func startProxy(
        options: [String: Any]? = nil,
        completionHandler: @escaping (Error?) -> Void
    ) {
        ExtensionXPCService.shared.registerDNSProvider(self)
        let store = RulesetStore(directory: containerURL())
        if let ruleset = store.loadIfActive() {
            applyRuleset(ruleset)
        }
        completionHandler(nil)
    }

    override func stopProxy(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        activeRuleset = nil
        domainMatcher = nil
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard activeRuleset != nil,
              let udpFlow = flow as? NEAppProxyUDPFlow else { return false }

        nonisolated(unsafe) let udp = udpFlow
        nonisolated(unsafe) let provider = self
        Task { @Sendable in
            do {
                try await provider.processUDPFlow(udp)
            } catch {
                udp.closeReadWithError(error)
                udp.closeWriteWithError(error)
            }
        }
        return true
    }

    func applyRuleset(_ ruleset: BlockRuleset) {
        activeRuleset = ruleset
        domainMatcher = DomainMatcher(rules: ruleset.domains)
    }

    func clearRuleset() {
        activeRuleset = nil
        domainMatcher = nil
    }

    private func processUDPFlow(_ flow: NEAppProxyUDPFlow) async throws {
        flow.open(withLocalFlowEndpoint: nil) { error in
            if let error { flow.closeReadWithError(error) }
        }

        while true {
            let (datagrams, endpoints) = try await readDatagrams(from: flow)
            guard !datagrams.isEmpty else { break }

            for (datagram, endpoint) in zip(datagrams, endpoints) {
                if let response = processDNSQuery(datagram, endpoint: endpoint) {
                    // Blocked -- send synthetic response back to the client
                    try await writeDatagrams([response], to: flow, endpoints: [endpoint])
                } else {
                    // Allowed -- forward to upstream DNS and relay the response
                    if let response = try await forwardToUpstream(
                        datagram: datagram,
                        endpoint: endpoint
                    ) {
                        try await writeDatagrams([response], to: flow, endpoints: [endpoint])
                    }
                }
            }
        }
    }

    private func processDNSQuery(_ data: Data, endpoint: NWEndpoint) -> Data? {
        guard let domain = extractDomainFromDNS(data),
              let ruleset = activeRuleset,
              let matcher = domainMatcher else { return nil }

        // Record IP->hostname mapping for the content filter
        if let ip = hostFromEndpoint(endpoint) {
            Self.sharedIPMap.set(ip: ip, hostname: domain)
        }

        let shouldBlock: Bool
        switch ruleset.mode {
        case .blocklist: shouldBlock = matcher.matches(domain)
        case .allowlist: shouldBlock = !matcher.matches(domain)
        }

        if shouldBlock {
            return buildBlockedDNSResponse(query: data)
        }
        return nil
    }

    // MARK: - Upstream DNS Forwarding

    private func forwardToUpstream(
        datagram: Data,
        endpoint: NWEndpoint
    ) async throws -> Data? {
        // Use the original endpoint the client was sending to (the system DNS server)
        let connection = NWConnection(to: endpoint, using: .udp)
        let continuationGuard = ContinuationGuard()

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { @Sendable state in
                switch state {
                case .failed(let error):
                    connection.cancel()
                    continuationGuard.resume(continuation, with: .failure(error))
                case .cancelled:
                    continuationGuard.resume(continuation, with: .success(nil))
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            connection.send(content: datagram, completion: .contentProcessed { @Sendable error in
                if let error {
                    connection.cancel()
                    continuationGuard.resume(continuation, with: .failure(error))
                    return
                }

                connection.receiveMessage { @Sendable data, _, _, receiveError in
                    defer { connection.cancel() }
                    if let receiveError {
                        continuationGuard.resume(continuation, with: .failure(receiveError))
                    } else {
                        continuationGuard.resume(continuation, with: .success(data))
                    }
                }
            })
        }
    }

    // MARK: - DNS Parsing

    private func hostFromEndpoint(_ endpoint: NWEndpoint) -> String? {
        switch endpoint {
        case .hostPort(let host, _):
            switch host {
            case .ipv4(let addr): return "\(addr)"
            case .ipv6(let addr): return "\(addr)"
            case .name(let name, _): return name
            @unknown default: return nil
            }
        default:
            return nil
        }
    }

    private func extractDomainFromDNS(_ data: Data) -> String? {
        guard data.count > 12 else { return nil }
        var labels: [String] = []
        var offset = 12
        while offset < data.count {
            let length = Int(data[offset])
            if length == 0 { break }
            offset += 1
            guard offset + length <= data.count else { return nil }
            guard let label = String(
                data: data[offset ..< offset + length],
                encoding: .utf8
            ) else { return nil }
            labels.append(label)
            offset += length
        }
        return labels.isEmpty ? nil : labels.joined(separator: ".")
    }

    private func buildBlockedDNSResponse(query: Data) -> Data {
        guard query.count >= 12 else { return Data() }
        var response = Data()
        response.append(query[0 ..< 2]) // Transaction ID
        response.append(contentsOf: [0x81, 0x80]) // Flags
        response.append(contentsOf: [0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])

        // Copy question section
        var offset = 12
        while offset < query.count {
            let len = Int(query[offset])
            if len == 0 { offset += 1; break }
            offset += 1 + len
        }
        offset += 4 // QTYPE + QCLASS
        if offset <= query.count {
            response.append(query[12 ..< offset])
        }

        // Answer: 0.0.0.0
        response.append(contentsOf: [0xC0, 0x0C]) // Name pointer
        response.append(contentsOf: [0x00, 0x01]) // Type A
        response.append(contentsOf: [0x00, 0x01]) // Class IN
        response.append(contentsOf: [0x00, 0x00, 0x00, 0x01]) // TTL 1s
        response.append(contentsOf: [0x00, 0x04]) // RDLENGTH
        response.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // 0.0.0.0
        return response
    }

    // MARK: - Helpers

    private func containerURL() -> URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.forge"
        ) ?? FileManager.default.temporaryDirectory
    }

    private func readDatagrams(
        from flow: NEAppProxyUDPFlow
    ) async throws -> ([Data], [NWEndpoint]) {
        let pairs: [(Data, NWEndpoint)] = try await withCheckedThrowingContinuation { continuation in
            flow.readDatagrams { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result ?? [])
                }
            }
        }
        return (pairs.map(\.0), pairs.map(\.1))
    }

    private func writeDatagrams(
        _ datagrams: [Data],
        to flow: NEAppProxyUDPFlow,
        endpoints: [NWEndpoint]
    ) async throws {
        let pairs = zip(datagrams, endpoints).map { ($0.0, $0.1) }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            flow.writeDatagrams(pairs) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

/// Thread-safe guard that ensures a continuation is resumed exactly once.
private final class ContinuationGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func resume(
        _ continuation: CheckedContinuation<Data?, any Error>,
        with result: Result<Data?, any Error>
    ) {
        let shouldResume = lock.withLock {
            guard !resumed else { return false }
            resumed = true
            return true
        }
        if shouldResume {
            continuation.resume(with: result)
        }
    }
}
