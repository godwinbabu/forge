import Foundation
import SwiftData

@Model
final class BlockProfile {
    var name: String
    var iconName: String
    var colorHex: String
    var isBlocklist: Bool
    var domains: [String]
    var appBundleIDs: [String]
    var expandSubdomains: Bool
    var allowLocalNetwork: Bool
    var clearBrowserCaches: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
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
        self.createdAt = .now
        self.updatedAt = .now
    }
}
