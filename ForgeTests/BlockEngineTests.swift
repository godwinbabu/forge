import Testing
import Foundation
@testable import ForgeKit

@Suite("BlockEngine Tests")
struct BlockEngineTests {

    @Test func buildRulesetFromProfile() {
        let config = RulesetConfig(
            domains: ["reddit.com", "twitter.com"],
            appBundleIDs: [],
            isBlocklist: true,
            expandSubdomains: true,
            allowLocalNetwork: true,
            durationSeconds: 3600,
            dohServerIPs: ["1.1.1.1"]
        )
        let ruleset = BlockEngineHelper.buildRuleset(config: config)

        #expect(ruleset.mode == .blocklist)
        #expect(ruleset.allowLocalNetwork == true)
        #expect(ruleset.expandCommonSubdomains == true)
        #expect(ruleset.dohServerIPs == ["1.1.1.1"])
        // With expansion: each domain + www + m + mobile + api = 5 each
        #expect(ruleset.domains.count == 10)
    }

    @Test func buildRulesetSetsCorrectEndDate() {
        let before = Date()
        let config = RulesetConfig(
            domains: ["test.com"],
            appBundleIDs: [],
            isBlocklist: true,
            expandSubdomains: false,
            allowLocalNetwork: true,
            durationSeconds: 1800,
            dohServerIPs: []
        )
        let ruleset = BlockEngineHelper.buildRuleset(config: config)
        let after = Date()

        #expect(ruleset.endDate >= before.addingTimeInterval(1800))
        #expect(ruleset.endDate <= after.addingTimeInterval(1800))
    }

    @Test func buildRulesetAllowlistMode() {
        let config = RulesetConfig(
            domains: ["allowed.com"],
            appBundleIDs: [],
            isBlocklist: false,
            expandSubdomains: false,
            allowLocalNetwork: true,
            durationSeconds: 3600,
            dohServerIPs: []
        )
        let ruleset = BlockEngineHelper.buildRuleset(config: config)
        #expect(ruleset.mode == .allowlist)
    }

    @Test func buildRulesetConvertsDomainsToExactRules() {
        let config = RulesetConfig(
            domains: ["reddit.com"],
            appBundleIDs: [],
            isBlocklist: true,
            expandSubdomains: false,
            allowLocalNetwork: true,
            durationSeconds: 3600,
            dohServerIPs: []
        )
        let ruleset = BlockEngineHelper.buildRuleset(config: config)
        #expect(ruleset.domains == [.exact("reddit.com")])
    }
}
