import Foundation

public enum ProfileSerializer {
    public static func encode(_ draft: ProfileDraft) throws -> Data {
        let preset = PresetProfileData(
            name: draft.name,
            iconName: draft.iconName,
            colorHex: draft.colorHex,
            isBlocklist: draft.isBlocklist,
            domains: draft.domains,
            appBundleIDs: draft.appBundleIDs,
            expandSubdomains: draft.expandSubdomains,
            allowLocalNetwork: draft.allowLocalNetwork,
            clearBrowserCaches: draft.clearBrowserCaches
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(preset)
    }

    public static func decode(_ data: Data) throws -> ProfileDraft {
        let preset = try JSONDecoder().decode(PresetProfileData.self, from: data)
        return ProfileDraft(
            name: preset.name,
            iconName: preset.iconName,
            colorHex: preset.colorHex,
            isBlocklist: preset.isBlocklist,
            domains: preset.domains,
            appBundleIDs: preset.appBundleIDs,
            expandSubdomains: preset.expandSubdomains,
            allowLocalNetwork: preset.allowLocalNetwork,
            clearBrowserCaches: preset.clearBrowserCaches
        )
    }
}
