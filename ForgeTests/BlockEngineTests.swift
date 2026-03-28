import Testing
import Foundation
@testable import ForgeKit

@Suite("BlockEngine Tests")
struct BlockEngineTests {

    @Test func buildRulesetFromProfile() {
        let domains = ["reddit.com", "twitter.com"]
        let ruleset = BlockEngineHelper.buildRuleset(
            domains: domains,
            appBundleIDs: [],
            isBlocklist: true,
            expandSubdomains: true,
            allowLocalNetwork: true,
            durationSeconds: 3600,
            dohServerIPs: ["1.1.1.1"]
        )

        #expect(ruleset.mode == .blocklist)
        #expect(ruleset.allowLocalNetwork == true)
        #expect(ruleset.expandCommonSubdomains == true)
        #expect(ruleset.dohServerIPs == ["1.1.1.1"])
        // With expansion: reddit.com + www.reddit.com + m.reddit.com + mobile.reddit.com + api.reddit.com
        // + twitter.com + www.twitter.com + m.twitter.com + mobile.twitter.com + api.twitter.com
        #expect(ruleset.domains.count == 10)
    }

    @Test func buildRulesetSetsCorrectEndDate() {
        let before = Date()
        let ruleset = BlockEngineHelper.buildRuleset(
            domains: ["test.com"],
            appBundleIDs: [],
            isBlocklist: true,
            expandSubdomains: false,
            allowLocalNetwork: true,
            durationSeconds: 1800,
            dohServerIPs: []
        )
        let after = Date()

        #expect(ruleset.endDate >= before.addingTimeInterval(1800))
        #expect(ruleset.endDate <= after.addingTimeInterval(1800))
    }

    @Test func buildRulesetAllowlistMode() {
        let ruleset = BlockEngineHelper.buildRuleset(
            domains: ["allowed.com"],
            appBundleIDs: [],
            isBlocklist: false,
            expandSubdomains: false,
            allowLocalNetwork: true,
            durationSeconds: 3600,
            dohServerIPs: []
        )
        #expect(ruleset.mode == .allowlist)
    }

    @Test func buildRulesetConvertsDomainsToExactRules() {
        let ruleset = BlockEngineHelper.buildRuleset(
            domains: ["reddit.com"],
            appBundleIDs: [],
            isBlocklist: true,
            expandSubdomains: false,
            allowLocalNetwork: true,
            durationSeconds: 3600,
            dohServerIPs: []
        )
        #expect(ruleset.domains == [.exact("reddit.com")])
    }
}
