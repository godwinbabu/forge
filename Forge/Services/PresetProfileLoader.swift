import Foundation

struct PresetProfileData: Codable {
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

enum PresetProfileLoader {
    static func load(from data: Data) throws -> [PresetProfileData] {
        try JSONDecoder().decode([PresetProfileData].self, from: data)
    }

    static func loadBundled() -> [PresetProfileData] {
        guard let url = Bundle.main.url(
            forResource: "PresetProfiles",
            withExtension: "json"
        ),
              let data = try? Data(contentsOf: url),
              let presets = try? load(from: data) else {
            return []
        }
        return presets
    }
}
