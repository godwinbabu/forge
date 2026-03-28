import SwiftUI
import ForgeKit

@MainActor @Observable
final class AppState {
    // Block state
    var isBlockActive = false
    var blockEndDate: Date?
    var activeProfileID: UUID?
    var activeProfileName: String?
    var activeProfileIcon: String?
    var activeProfileColor: String?
    var blockedAttemptCount: Int = 0

    // UI state
    var selectedSidebarItem: SidebarItem = .dashboard
    var showingDurationPicker = false
    var selectedDuration: TimeInterval = 3600 // 1 hour default

    // Bypass state
    var isBypassActive = false
    var bypassStage: BypassStage = .reenablePrompt
    var cooldownEndDate: Date?

    func activateBlock(
        profileID: UUID,
        profileName: String,
        profileIcon: String,
        profileColor: String,
        endDate: Date
    ) {
        isBlockActive = true
        blockEndDate = endDate
        activeProfileID = profileID
        activeProfileName = profileName
        activeProfileIcon = profileIcon
        activeProfileColor = profileColor
        blockedAttemptCount = 0
    }

    func deactivateBlock() {
        isBlockActive = false
        blockEndDate = nil
        activeProfileID = nil
        activeProfileName = nil
        activeProfileIcon = nil
        activeProfileColor = nil
        blockedAttemptCount = 0
    }

    func extendBlock(by seconds: TimeInterval) {
        guard let current = blockEndDate else { return }
        blockEndDate = current.addingTimeInterval(seconds)
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case profiles = "Profiles"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.bottom.50percent"
        case .profiles: "person.crop.rectangle.stack"
        case .settings: "gear"
        }
    }
}
