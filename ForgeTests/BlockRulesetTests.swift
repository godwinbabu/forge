import Testing
import Foundation
@testable import ForgeKit

@Suite("BlockRuleset Tests")
struct BlockRulesetTests {
    static func makeSampleRuleset(
        mode: BlockMode = .blocklist,
        endDate: Date = .distantFuture
    ) -> BlockRuleset {
        BlockRuleset(
            id: UUID(),
            mode: mode,
            domains: [.exact("reddit.com"), .wildcard("*.twitter.com")],
            appBundleIDs: [],
            dohServerIPs: ["1.1.1.1", "8.8.8.8"],
            allowLocalNetwork: true,
            expandCommonSubdomains: true,
            startDate: .now,
            endDate: endDate
        )
    }

    @Test func encodingRoundtrip() throws {
        let original = Self.makeSampleRuleset()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BlockRuleset.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.mode == original.mode)
        #expect(decoded.domains.count == original.domains.count)
        #expect(decoded.dohServerIPs == ["1.1.1.1", "8.8.8.8"])
    }

    @Test func blocklistModeBlocksMatchedDomain() {
        let ruleset = Self.makeSampleRuleset(mode: .blocklist)
        #expect(ruleset.shouldBlock(hostname: "reddit.com") == true)
        #expect(ruleset.shouldBlock(hostname: "m.twitter.com") == true)
    }

    @Test func blocklistModeAllowsUnmatchedDomain() {
        let ruleset = Self.makeSampleRuleset(mode: .blocklist)
        #expect(ruleset.shouldBlock(hostname: "google.com") == false)
    }

    @Test func allowlistModeAllowsMatchedDomain() {
        let ruleset = Self.makeSampleRuleset(mode: .allowlist)
        #expect(ruleset.shouldBlock(hostname: "reddit.com") == false)
    }

    @Test func allowlistModeBlocksUnmatchedDomain() {
        let ruleset = Self.makeSampleRuleset(mode: .allowlist)
        #expect(ruleset.shouldBlock(hostname: "google.com") == true)
    }

    @Test func isExpiredReturnsTrueAfterEndDate() {
        let ruleset = Self.makeSampleRuleset(endDate: .now.addingTimeInterval(-60))
        #expect(ruleset.isExpired == true)
    }

    @Test func isExpiredReturnsFalseBeforeEndDate() {
        let ruleset = Self.makeSampleRuleset(endDate: .now.addingTimeInterval(3600))
        #expect(ruleset.isExpired == false)
    }

    @Test func nilHostnameNotBlockedInBlocklistMode() {
        let ruleset = Self.makeSampleRuleset(mode: .blocklist)
        #expect(ruleset.shouldBlock(hostname: nil) == false)
    }

    @Test func nilHostnameBlockedInAllowlistMode() {
        let ruleset = Self.makeSampleRuleset(mode: .allowlist)
        #expect(ruleset.shouldBlock(hostname: nil) == true)
    }

    @Test func expandedSubdomainsAddWwwAndMobileVariants() {
        let ruleset = BlockRuleset(
            id: UUID(), mode: .blocklist,
            domains: [.exact("reddit.com")],
            appBundleIDs: [], dohServerIPs: [],
            allowLocalNetwork: true, expandCommonSubdomains: true,
            startDate: .now, endDate: .distantFuture
        )
        #expect(ruleset.shouldBlock(hostname: "www.reddit.com") == true)
        #expect(ruleset.shouldBlock(hostname: "m.reddit.com") == true)
    }

    @Test func noExpansionWhenDisabled() {
        let ruleset = BlockRuleset(
            id: UUID(), mode: .blocklist,
            domains: [.exact("reddit.com")],
            appBundleIDs: [], dohServerIPs: [],
            allowLocalNetwork: true, expandCommonSubdomains: false,
            startDate: .now, endDate: .distantFuture
        )
        #expect(ruleset.shouldBlock(hostname: "www.reddit.com") == false)
    }
}
