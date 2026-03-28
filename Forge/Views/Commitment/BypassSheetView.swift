import SwiftUI
import SwiftData
import ForgeKit

struct BypassSheetView: View {
    @Bindable var appState: AppState
    let blockEngine: BlockEngine
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            switch appState.bypassStage {
            case .reenablePrompt:
                ReenablePromptView(
                    blockEndDate: appState.blockEndDate ?? .now,
                    blockedAttemptCount: appState.blockedAttemptCount,
                    onRequestQuit: {
                        advanceTo(.typingChallenge)
                    }
                )

            case .typingChallenge:
                TypingChallengeView(
                    remainingTime: formatRemainingTime(),
                    onCompleted: {
                        let endDate = CooldownState.newCooldownEndDate()
                        appState.cooldownEndDate = endDate
                        let defaults = UserDefaults(suiteName: "group.app.forge") ?? .standard
                        BypassPersistence.saveCooldownEnd(endDate, to: defaults)
                        advanceTo(.cooldown)
                    },
                    onCancel: {
                        cancelBypass()
                    }
                )

            case .cooldown:
                CooldownTimerView(
                    cooldownEndDate: appState.cooldownEndDate ?? CooldownState.newCooldownEndDate(),
                    onBypassed: {
                        Task {
                            await blockEngine.completeBypass(
                                appState: appState,
                                modelContext: modelContext
                            )
                        }
                    },
                    onCancel: {
                        cancelBypass()
                    }
                )
            }
        }
    }

    private func advanceTo(_ stage: BypassStage) {
        appState.bypassStage = stage
        let defaults = UserDefaults(suiteName: "group.app.forge") ?? .standard
        BypassPersistence.save(stage: stage, to: defaults)
    }

    private func cancelBypass() {
        // Go back to Stage 1 so user is prompted to re-enable
        appState.bypassStage = .reenablePrompt
        appState.cooldownEndDate = nil
        let defaults = UserDefaults(suiteName: "group.app.forge") ?? .standard
        BypassPersistence.save(stage: .reenablePrompt, to: defaults)
        defaults.removeObject(forKey: BypassPersistence.Keys.cooldownEndDate)
    }

    private func formatRemainingTime() -> String {
        guard let end = appState.blockEndDate else { return "unknown time" }
        let remaining = end.timeIntervalSinceNow
        guard remaining > 0 else { return "0 minutes" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}
