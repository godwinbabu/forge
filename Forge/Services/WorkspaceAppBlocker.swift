import AppKit
import ForgeKit

@MainActor
final class WorkspaceAppBlocker {
    private var blockedBundleIDs = Set<String>()
    private var observer: NSObjectProtocol?

    func activate(bundleIDs: Set<String>) {
        blockedBundleIDs = bundleIDs
        guard !bundleIDs.isEmpty else { return }

        terminateRunningBlockedApps()
        startObservingLaunches()
    }

    func deactivate() {
        blockedBundleIDs.removeAll()
        stopObservingLaunches()
    }

    // MARK: - Running App Termination

    private func terminateRunningBlockedApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let bundleID = app.bundleIdentifier,
                  blockedBundleIDs.contains(bundleID),
                  !ProtectedApps.isProtected(bundleID) else { continue }

            app.terminate()
            // Force terminate after 5 seconds if still running
            Task {
                try? await Task.sleep(for: .seconds(5))
                if !app.isTerminated {
                    app.forceTerminate()
                }
            }
        }
    }

    // MARK: - Launch Observation

    private func startObservingLaunches() {
        stopObservingLaunches()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }

            Task { @MainActor in
                if self.blockedBundleIDs.contains(bundleID),
                   !ProtectedApps.isProtected(bundleID) {
                    app.terminate()
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if !app.isTerminated {
                            app.forceTerminate()
                        }
                    }
                }
            }
        }
    }

    private func stopObservingLaunches() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }
}
