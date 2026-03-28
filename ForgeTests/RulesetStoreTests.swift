import Testing
import Foundation
@testable import ForgeKit

@Suite("RulesetStore Tests")
struct RulesetStoreTests {
    private func makeTemporaryStore() -> RulesetStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return RulesetStore(directory: dir)
    }

    private func makeSampleRuleset() -> BlockRuleset {
        BlockRuleset(
            id: UUID(), mode: .blocklist,
            domains: [.exact("reddit.com"), .wildcard("*.twitter.com")],
            appBundleIDs: ["com.hnc.Discord"], dohServerIPs: ["1.1.1.1"],
            allowLocalNetwork: true, expandCommonSubdomains: false,
            startDate: .now, endDate: .now.addingTimeInterval(3600)
        )
    }

    @Test func saveAndLoadRoundtrip() throws {
        let store = makeTemporaryStore()
        let original = makeSampleRuleset()
        try store.save(original)
        let loaded = try #require(store.load())
        #expect(loaded.id == original.id)
        #expect(loaded.mode == .blocklist)
        #expect(loaded.domains.count == 2)
        #expect(loaded.appBundleIDs == ["com.hnc.Discord"])
    }

    @Test func loadReturnsNilWhenEmpty() {
        let store = makeTemporaryStore()
        #expect(store.load() == nil)
    }

    @Test func deleteRemovesStoredRuleset() throws {
        let store = makeTemporaryStore()
        try store.save(makeSampleRuleset())
        store.delete()
        #expect(store.load() == nil)
    }

    @Test func saveOverwritesPreviousRuleset() throws {
        let store = makeTemporaryStore()
        try store.save(makeSampleRuleset())
        let second = BlockRuleset(
            id: UUID(), mode: .allowlist,
            domains: [.exact("only-this.com")], appBundleIDs: [], dohServerIPs: [],
            allowLocalNetwork: false, expandCommonSubdomains: false,
            startDate: .now, endDate: .now.addingTimeInterval(7200)
        )
        try store.save(second)
        let loaded = try #require(store.load())
        #expect(loaded.id == second.id)
        #expect(loaded.mode == .allowlist)
    }

    @Test func loadExpiredRulesetReturnsNilAndCleans() throws {
        let store = makeTemporaryStore()
        let expired = BlockRuleset(
            id: UUID(), mode: .blocklist,
            domains: [.exact("reddit.com")], appBundleIDs: [], dohServerIPs: [],
            allowLocalNetwork: true, expandCommonSubdomains: false,
            startDate: .now.addingTimeInterval(-7200), endDate: .now.addingTimeInterval(-3600)
        )
        try store.save(expired)
        #expect(store.loadIfActive() == nil)
    }
}
