import Testing
import Foundation
@testable import ForgeKit

@Suite("ProfileSerializer Tests")
struct ProfileSerializerTests {

    @Test func encodeDecodeRoundtrip() throws {
        let draft = ProfileDraft(
            name: "Work Mode",
            iconName: "briefcase.fill",
            colorHex: "#FF3B30",
            isBlocklist: true,
            domains: ["reddit.com", "twitter.com"],
            appBundleIDs: ["com.valvesoftware.steam"],
            expandSubdomains: true,
            allowLocalNetwork: false,
            clearBrowserCaches: true
        )

        let data = try ProfileSerializer.encode(draft)
        let decoded = try ProfileSerializer.decode(data)

        #expect(decoded.name == draft.name)
        #expect(decoded.iconName == draft.iconName)
        #expect(decoded.colorHex == draft.colorHex)
        #expect(decoded.isBlocklist == draft.isBlocklist)
        #expect(decoded.domains == draft.domains)
        #expect(decoded.appBundleIDs == draft.appBundleIDs)
        #expect(decoded.expandSubdomains == draft.expandSubdomains)
        #expect(decoded.allowLocalNetwork == draft.allowLocalNetwork)
        #expect(decoded.clearBrowserCaches == draft.clearBrowserCaches)
    }

    @Test func decodeRejectsInvalidJSON() {
        let badData = Data("not json".utf8)
        #expect(throws: (any Error).self) {
            try ProfileSerializer.decode(badData)
        }
    }

    @Test func encodedJSONIsHumanReadable() throws {
        let draft = ProfileDraft(name: "Test", domains: ["example.com"])
        let data = try ProfileSerializer.encode(draft)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"name\""))
        #expect(json.contains("\"Test\""))
    }
}
