import Network
import NetworkExtension
import ForgeKit

final class FilterDataProvider: NEFilterDataProvider {
    private var activeRuleset: BlockRuleset?
    private var ipMap: IPHostnameMap { DNSProxyProvider.sharedIPMap }
    private var dohIPs = Set<String>()
    private var domainMatcher: DomainMatcher?
    private var cidrMatcher: CIDRMatcher?

    private static let essentialPorts: Set<Int> = [53, 123, 67, 68, 5353]

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        ExtensionXPCService.shared.registerFilterProvider(self)
        let store = RulesetStore(directory: containerURL())
        if let ruleset = store.loadIfActive() {
            applyRuleset(ruleset)
        }
        completionHandler(nil)
    }

    override func stopFilter(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        activeRuleset = nil
        domainMatcher = nil
        cidrMatcher = nil
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let ruleset = activeRuleset else { return .allow() }

        if ruleset.isExpired {
            clearRuleset()
            return .allow()
        }

        guard let socketFlow = flow as? NEFilterSocketFlow else { return .allow() }

        if let ipVerdict = evaluateIPRules(socketFlow, ruleset: ruleset) {
            return ipVerdict
        }

        // Resolve hostname
        let hostname = socketFlow.remoteHostname
            ?? socketFlow.remoteIP.flatMap { ipMap.hostname(for: $0) }

        if let hostname = hostname {
            // Check port-specific rules when port info is available
            if let port = socketFlow.remotePort {
                let portMatched = domainMatcher?.matchesWithPort(hostname, port: port) ?? false
                if portMatched {
                    switch ruleset.mode {
                    case .blocklist: return .drop()
                    case .allowlist: return .allow()
                    }
                }
            }
            return verdict(for: hostname, ruleset: ruleset)
        }

        // No hostname -- inspect outbound data for SNI in allowlist mode
        if ruleset.mode == .allowlist {
            return .filterDataVerdict(
                withFilterInbound: false,
                peekInboundBytes: 0,
                filterOutbound: true,
                peekOutboundBytes: Int.max
            )
        }

        return .allow()
    }

    override func handleOutboundData(
        from flow: NEFilterFlow,
        readBytesStartOffset offset: Int,
        readBytes: Data
    ) -> NEFilterDataVerdict {
        guard let ruleset = activeRuleset,
              let socketFlow = flow as? NEFilterSocketFlow else {
            return .allow()
        }

        if let hostname = SNIExtractor.extractHostname(from: readBytes) {
            if let ip = socketFlow.remoteIP {
                ipMap.set(ip: ip, hostname: hostname)
            }
            let shouldDrop: Bool
            let matched = domainMatcher?.matches(hostname) ?? false
            switch ruleset.mode {
            case .blocklist: shouldDrop = matched
            case .allowlist: shouldDrop = !matched
            }
            return shouldDrop ? .drop() : .allow()
        }

        return ruleset.mode == .allowlist ? .drop() : .allow()
    }

    // MARK: - Internal

    func applyRuleset(_ ruleset: BlockRuleset) {
        activeRuleset = ruleset
        domainMatcher = DomainMatcher(rules: ruleset.domains)
        cidrMatcher = CIDRMatcher(rules: ruleset.domains)
        dohIPs = Set(ruleset.dohServerIPs)
    }

    func clearRuleset() {
        activeRuleset = nil
        domainMatcher = nil
        cidrMatcher = nil
        dohIPs.removeAll()
        let store = RulesetStore(directory: containerURL())
        store.delete()
    }

    private func evaluateIPRules(
        _ socketFlow: NEFilterSocketFlow,
        ruleset: BlockRuleset
    ) -> NEFilterNewFlowVerdict? {
        // Allow essential services in allowlist mode
        if ruleset.mode == .allowlist {
            if let port = socketFlow.remotePort, Self.essentialPorts.contains(port) {
                return .allow()
            }
        }

        guard let ip = socketFlow.remoteIP else { return nil }

        // Check CIDR rules first (before DoH) so allowlist CIDR entries are honoured
        if cidrMatcher?.matches(ip: ip) ?? false {
            switch ruleset.mode {
            case .blocklist: return .drop()
            case .allowlist: return nil // CIDR match in allowlist means allowed, continue
            }
        }

        // Block DoH only in blocklist mode to avoid bypassing allowlist CIDR rules
        if ruleset.mode == .blocklist && dohIPs.contains(ip) {
            return .drop()
        }

        return nil
    }

    private func verdict(for hostname: String, ruleset: BlockRuleset) -> NEFilterNewFlowVerdict {
        let matched = domainMatcher?.matches(hostname) ?? false
        switch ruleset.mode {
        case .blocklist: return matched ? .drop() : .allow()
        case .allowlist: return matched ? .allow() : .drop()
        }
    }

    private func containerURL() -> URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.forge"
        ) ?? FileManager.default.temporaryDirectory
    }
}

extension NEFilterSocketFlow {
    var remoteIP: String? {
        switch remoteFlowEndpoint {
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

    var remotePort: Int? {
        switch remoteFlowEndpoint {
        case .hostPort(_, let port):
            return Int(port.rawValue)
        default:
            return nil
        }
    }
}
