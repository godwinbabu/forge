import Foundation
import SwiftData

@Model
final class BlockProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var isBlocklist: Bool
    var domains: [String]
    var appBundleIDs: [String]
    var expandSubdomains: Bool
    var allowLocalNetwork: Bool
    var clearBrowserCaches: Bool
    var isPinned: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "shield.fill",
        colorHex: String = "#007AFF",
        isBlocklist: Bool = true,
        domains: [String] = [],
        appBundleIDs: [String] = [],
        expandSubdomains: Bool = true,
        allowLocalNetwork: Bool = true,
        clearBrowserCaches: Bool = false,
        isPinned: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isBlocklist = isBlocklist
        self.domains = domains
        self.appBundleIDs = appBundleIDs
        self.expandSubdomains = expandSubdomains
        self.allowLocalNetwork = allowLocalNetwork
        self.clearBrowserCaches = clearBrowserCaches
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.updatedAt = .now
    }
}
