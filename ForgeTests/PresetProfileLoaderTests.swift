import Testing
import Foundation

/// Mirrors PresetProfileData for testing JSON decoding independently
private struct TestPresetProfileData: Codable {
    let name: String
    let iconName: String
    let colorHex: String
    let isBlocklist: Bool
    let domains: [String]
    let appBundleIDs: [String]
    let expandSubdomains: Bool
    let allowLocalNetwork: Bool
    let clearBrowserCaches: Bool
}

@Suite("PresetProfileLoader Tests")
struct PresetProfileLoaderTests {
    @Test func loadsPresetsFromJSON() throws {
        let jsonString = """
        [{"name":"Social Media",\
        "iconName":"bubble.left.and.bubble.right.fill",\
        "colorHex":"#FF3B30","isBlocklist":true,\
        "domains":["facebook.com","instagram.com"],"appBundleIDs":[],\
        "expandSubdomains":true,"allowLocalNetwork":true,\
        "clearBrowserCaches":false}]
        """
        let json = Data(jsonString.utf8)

        let presets = try JSONDecoder().decode(
            [TestPresetProfileData].self,
            from: json
        )
        #expect(presets.count == 1)
        #expect(presets[0].name == "Social Media")
        #expect(presets[0].domains == ["facebook.com", "instagram.com"])
    }

    @Test func emptyArrayProducesNoPresets() throws {
        let json = Data("[]".utf8)
        let presets = try JSONDecoder().decode(
            [TestPresetProfileData].self,
            from: json
        )
        #expect(presets.isEmpty)
    }
}
