import Foundation

public struct RulesetConfig: Sendable {
    public let domains: [String]
    public let appBundleIDs: [String]
    public let isBlocklist: Bool
    public let expandSubdomains: Bool
    public let allowLocalNetwork: Bool
    public let durationSeconds: TimeInterval
    public let dohServerIPs: [String]

    public init(
        domains: [String],
        appBundleIDs: [String],
        isBlocklist: Bool,
        expandSubdomains: Bool,
        allowLocalNetwork: Bool,
        durationSeconds: TimeInterval,
        dohServerIPs: [String]
    ) {
        self.domains = domains
        self.appBundleIDs = appBundleIDs
        self.isBlocklist = isBlocklist
        self.expandSubdomains = expandSubdomains
        self.allowLocalNetwork = allowLocalNetwork
        self.durationSeconds = durationSeconds
        self.dohServerIPs = dohServerIPs
    }
}

public enum BlockEngineHelper {
    public static func buildRuleset(config: RulesetConfig) -> BlockRuleset {
        let domainRules = config.domains.map { DomainRule.exact($0) }

        return BlockRuleset(
            id: UUID(),
            mode: config.isBlocklist ? .blocklist : .allowlist,
            domains: domainRules,
            appBundleIDs: config.appBundleIDs,
            dohServerIPs: config.dohServerIPs,
            allowLocalNetwork: config.allowLocalNetwork,
            expandCommonSubdomains: config.expandSubdomains,
            startDate: .now,
            endDate: .now.addingTimeInterval(config.durationSeconds)
        )
    }
}
