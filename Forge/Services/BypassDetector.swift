import Foundation
import NetworkExtension
import ForgeKit

@MainActor
final class BypassDetector {
    private var timer: Timer?
    private let pollInterval: TimeInterval = 5.0

    func startMonitoring(appState: AppState) {
        stopMonitoring()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkExtensionStatus(appState: appState)
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkExtensionStatus(appState: AppState) {
        guard appState.isBlockActive else { return }
        let enabled = NEFilterManager.shared().isEnabled

        if !enabled && !appState.isBypassActive {
            // Extension was disabled — start bypass flow
            appState.isBypassActive = true
            appState.bypassStage = .reenablePrompt
            let defaults = UserDefaults(suiteName: "group.app.forge") ?? .standard
            BypassPersistence.save(stage: .reenablePrompt, to: defaults)
        } else if enabled && appState.isBypassActive {
            // Extension was re-enabled — cancel bypass flow
            appState.isBypassActive = false
            appState.bypassStage = .reenablePrompt
            appState.cooldownEndDate = nil
            let defaults = UserDefaults(suiteName: "group.app.forge") ?? .standard
            BypassPersistence.clear(from: defaults)
        }
    }
}
