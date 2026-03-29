import Testing
@testable import ForgeKit

@Suite("ProfileDraft Tests")
struct ProfileDraftTests {

    @Test func defaultsHaveExpectedValues() {
        let draft = ProfileDraft.defaults
        #expect(draft.name == "")
        #expect(draft.iconName == "shield.fill")
        #expect(draft.colorHex == "#007AFF")
        #expect(draft.isBlocklist == true)
        #expect(draft.domains.isEmpty)
        #expect(draft.appBundleIDs.isEmpty)
        #expect(draft.expandSubdomains == true)
        #expect(draft.allowLocalNetwork == true)
        #expect(draft.clearBrowserCaches == false)
    }

    @Test func initWithAllFields() {
        let draft = ProfileDraft(
            name: "Work",
            iconName: "briefcase.fill",
            colorHex: "#FF0000",
            isBlocklist: false,
            domains: ["reddit.com"],
            appBundleIDs: ["com.valvesoftware.steam"],
            expandSubdomains: false,
            allowLocalNetwork: false,
            clearBrowserCaches: true
        )
        #expect(draft.name == "Work")
        #expect(draft.iconName == "briefcase.fill")
        #expect(draft.colorHex == "#FF0000")
        #expect(draft.isBlocklist == false)
        #expect(draft.domains == ["reddit.com"])
        #expect(draft.appBundleIDs == ["com.valvesoftware.steam"])
        #expect(draft.expandSubdomains == false)
        #expect(draft.allowLocalNetwork == false)
        #expect(draft.clearBrowserCaches == true)
    }
}
