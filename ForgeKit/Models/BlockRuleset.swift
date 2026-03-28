import Foundation

public struct BlockRuleset: Codable, Sendable {
    public let id: UUID
    public let mode: BlockMode
    public let domains: [DomainRule]
    public let appBundleIDs: [String]
    public let dohServerIPs: [String]
    public let allowLocalNetwork: Bool
    public let expandCommonSubdomains: Bool
    public let startDate: Date
    public let endDate: Date

    private static let commonSubdomainPrefixes = ["www.", "m.", "mobile.", "api."]

    public init(
        id: UUID, mode: BlockMode, domains: [DomainRule], appBundleIDs: [String],
        dohServerIPs: [String], allowLocalNetwork: Bool, expandCommonSubdomains: Bool,
        startDate: Date, endDate: Date
    ) {
        self.id = id
        self.mode = mode
        self.appBundleIDs = appBundleIDs
        self.dohServerIPs = dohServerIPs
        self.allowLocalNetwork = allowLocalNetwork
        self.expandCommonSubdomains = expandCommonSubdomains
        self.startDate = startDate
        self.endDate = endDate

        if expandCommonSubdomains {
            var expanded = domains
            for rule in domains {
                if case .exact(let domain) = rule {
                    for prefix in Self.commonSubdomainPrefixes {
                        expanded.append(.exact(prefix + domain))
                    }
                }
            }
            self.domains = expanded
        } else {
            self.domains = domains
        }
    }

    public var isExpired: Bool { Date() >= endDate }

    public func shouldBlock(hostname: String?) -> Bool {
        let matcher = DomainMatcher(rules: domains)
        let matched = matcher.matches(hostname)
        switch mode {
        case .blocklist: return matched
        case .allowlist: return !matched
        }
    }
}
