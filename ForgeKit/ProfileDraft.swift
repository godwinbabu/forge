import Foundation

public struct ProfileDraft: Sendable {
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var isBlocklist: Bool
    public var domains: [String]
    public var appBundleIDs: [String]
    public var expandSubdomains: Bool
    public var allowLocalNetwork: Bool
    public var clearBrowserCaches: Bool

    public init(
        name: String = "",
        iconName: String = "shield.fill",
        colorHex: String = "#007AFF",
        isBlocklist: Bool = true,
        domains: [String] = [],
        appBundleIDs: [String] = [],
        expandSubdomains: Bool = true,
        allowLocalNetwork: Bool = true,
        clearBrowserCaches: Bool = false
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

    public static var defaults: ProfileDraft { ProfileDraft() }
}
