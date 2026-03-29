import Foundation
import ForgeKit

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
