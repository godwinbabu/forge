import Foundation

public enum BlockEngineHelper {
    public static func buildRuleset(
        domains: [String],
        appBundleIDs: [String],
        isBlocklist: Bool,
        expandSubdomains: Bool,
        allowLocalNetwork: Bool,
        durationSeconds: TimeInterval,
        dohServerIPs: [String]
    ) -> BlockRuleset {
        let domainRules = domains.map { DomainRule.exact($0) }

        return BlockRuleset(
            id: UUID(),
            mode: isBlocklist ? .blocklist : .allowlist,
            domains: domainRules,
            appBundleIDs: appBundleIDs,
            dohServerIPs: dohServerIPs,
            allowLocalNetwork: allowLocalNetwork,
            expandCommonSubdomains: expandSubdomains,
            startDate: .now,
            endDate: .now.addingTimeInterval(durationSeconds)
        )
    }
}
