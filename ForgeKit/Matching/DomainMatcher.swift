import Foundation

public struct DomainMatcher: Sendable {
    private let exactDomains: Set<String>
    private let wildcardSuffixes: [String]
    private let portRules: [(String, Int)]

    public init(rules: [DomainRule]) {
        var exact = Set<String>()
        var wildcards = [String]()
        var ports = [(String, Int)]()

        for rule in rules {
            switch rule {
            case .exact(let domain):
                exact.insert(domain.lowercased())
            case .wildcard(let pattern):
                let suffix = String(pattern.dropFirst(1)).lowercased()
                wildcards.append(suffix)
            case .cidr:
                break
            case .portSpecific(let domain, let port):
                ports.append((domain.lowercased(), port))
            }
        }

        self.exactDomains = exact
        self.wildcardSuffixes = wildcards
        self.portRules = ports
    }

    public func matches(_ hostname: String?) -> Bool {
        guard let hostname = hostname?.lowercased() else { return false }

        if exactDomains.contains(hostname) {
            return true
        }

        for suffix in wildcardSuffixes {
            if hostname.hasSuffix(suffix) && hostname.count > suffix.count {
                return true
            }
        }

        return false
    }

    public func matchesWithPort(_ hostname: String?, port: Int) -> Bool {
        guard let hostname = hostname?.lowercased() else { return false }

        for (domain, rulePort) in portRules where rulePort == port {
            if hostname == domain {
                return true
            }
        }

        return false
    }
}
