import Foundation

public struct PresetProfileData: Codable, Sendable {
    public let name: String
    public let iconName: String
    public let colorHex: String
    public let isBlocklist: Bool
    public let domains: [String]
    public let appBundleIDs: [String]
    public let expandSubdomains: Bool
    public let allowLocalNetwork: Bool
    public let clearBrowserCaches: Bool

    public init(
        name: String,
        iconName: String,
        colorHex: String,
        isBlocklist: Bool,
        domains: [String],
        appBundleIDs: [String],
        expandSubdomains: Bool,
        allowLocalNetwork: Bool,
        clearBrowserCaches: Bool
    ) {
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isBlocklist = isBlocklist
        self.domains = domains
        self.appBundleIDs = appBundleIDs
        self.expandSubdomains = expandSubdomains
        self.allowLocalNetwork = allowLocalNetwork
        self.clearBrowserCaches = clearBrowserCaches
    }
}
