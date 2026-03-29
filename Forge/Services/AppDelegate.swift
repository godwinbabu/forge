import AppKit

final class ForgeAppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState, appState.isBlockActive else {
            return .terminateNow
        }
        // Block is active — prevent quit
        return .terminateCancel
    }
}
