import Foundation
import SwiftData
import ForgeKit

@MainActor @Observable
final class BlockEngine {
    private let xpcClient = ExtensionXPCClient()
    private var expiryTimer: Timer?
    private let workspaceAppBlocker = WorkspaceAppBlocker()

    func startBlock(
        profile: BlockProfile,
        duration: TimeInterval,
        dohServerIPs: [String],
        appState: AppState,
        modelContext: ModelContext
    ) async throws {
        let domains = profile.domains
        let appBundleIDs = profile.appBundleIDs
        let isBlocklist = profile.isBlocklist
        let expandSubdomains = profile.expandSubdomains
        let allowLocalNetwork = profile.allowLocalNetwork
        let profileID = profile.id
        let profileName = profile.name
        let profileIconName = profile.iconName
        let profileColorHex = profile.colorHex

        let config = RulesetConfig(
            domains: domains,
            appBundleIDs: appBundleIDs,
            isBlocklist: isBlocklist,
            expandSubdomains: expandSubdomains,
            allowLocalNetwork: allowLocalNetwork,
            durationSeconds: duration,
            dohServerIPs: dohServerIPs
        )
        let ruleset = BlockEngineHelper.buildRuleset(config: config)

        try await xpcClient.updateRuleset(ruleset)

        let session = BlockSession(
            profileID: profileID,
            profileName: profileName,
            startDate: ruleset.startDate,
            endDate: ruleset.endDate,
            domains: domains,
            isBlocklist: isBlocklist,
            trigger: "manual"
        )
        modelContext.insert(session)
        try modelContext.save()

        appState.activateBlock(
            profileID: profileID,
            profileName: profileName,
            profileIcon: profileIconName,
            profileColor: profileColorHex,
            endDate: ruleset.endDate
        )

        scheduleExpiryTimer(endDate: ruleset.endDate, appState: appState)
        writeSharedStatus(appState: appState)

        if !appBundleIDs.isEmpty {
            workspaceAppBlocker.activate(bundleIDs: Set(appBundleIDs))
        }
    }

    func extendBlock(
        by seconds: TimeInterval,
        appState: AppState
    ) async throws {
        guard let currentEnd = appState.blockEndDate else { return }
        let newEnd = currentEnd.addingTimeInterval(seconds)

        // Get current status and update
        if let current = await xpcClient.getStatus() {
            let extended = BlockRuleset(
                id: current.id,
                mode: current.mode,
                domains: current.domains,
                appBundleIDs: current.appBundleIDs,
                dohServerIPs: current.dohServerIPs,
                allowLocalNetwork: current.allowLocalNetwork,
                expandCommonSubdomains: false, // Already expanded
                startDate: current.startDate,
                endDate: newEnd
            )
            try await xpcClient.updateRuleset(extended)
        }

        appState.extendBlock(by: seconds)

        scheduleExpiryTimer(endDate: newEnd, appState: appState)
        writeSharedStatus(appState: appState)
    }

    func stopBlock(appState: AppState) async {
        expiryTimer?.invalidate()
        expiryTimer = nil

        do {
            try await xpcClient.deactivateRuleset()
        } catch {
            print("[BlockEngine] Failed to deactivate ruleset: \(error)")
        }

        appState.deactivateBlock()
        workspaceAppBlocker.deactivate()
        writeSharedStatus(appState: appState)
    }

    func completeBypass(appState: AppState, modelContext: ModelContext) async {
        // Update existing session's trigger to "bypass"
        if let profileName = appState.activeProfileName {
            let descriptor = FetchDescriptor<BlockSession>(
                predicate: #Predicate<BlockSession> { session in
                    session.profileName == profileName && session.trigger == "manual"
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            if let existingSession = try? modelContext.fetch(descriptor).first {
                existingSession.trigger = "bypass"
                existingSession.actualEndDate = Date()
                try? modelContext.save()
            }
        }

        // Clear bypass persistence
        let defaults = UserDefaults(suiteName: "group.app.forge") ?? .standard
        BypassPersistence.clear(from: defaults)

        // Stop the block
        await stopBlock(appState: appState)

        // Clear bypass UI state
        appState.isBypassActive = false
        appState.bypassStage = .reenablePrompt
        appState.cooldownEndDate = nil
    }

    func checkExistingBlock(appState: AppState) async {
        guard let ruleset = await xpcClient.getStatus() else { return }
        if ruleset.isExpired { return }

        appState.activateBlock(
            profileID: UUID(), // Unknown from extension
            profileName: "Active Block",
            profileIcon: "flame.fill",
            profileColor: "#FF9500",
            endDate: ruleset.endDate
        )

        scheduleExpiryTimer(endDate: ruleset.endDate, appState: appState)

        if !ruleset.appBundleIDs.isEmpty {
            workspaceAppBlocker.activate(bundleIDs: Set(ruleset.appBundleIDs))
        }
    }

    private func writeSharedStatus(appState: AppState) {
        guard let defaults = UserDefaults(
            suiteName: "group.app.forge"
        ) else { return }
        defaults.set(appState.isBlockActive, forKey: "isBlockActive")
        defaults.set(appState.blockEndDate, forKey: "blockEndDate")
        defaults.set(
            appState.activeProfileName,
            forKey: "activeProfileName"
        )
        defaults.set(
            appState.blockedAttemptCount,
            forKey: "blockedAttemptCount"
        )
    }

    private func scheduleExpiryTimer(endDate: Date, appState: AppState) {
        expiryTimer?.invalidate()
        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else {
            Task { await stopBlock(appState: appState) }
            return
        }

        expiryTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.stopBlock(appState: appState)
            }
        }
    }
}
