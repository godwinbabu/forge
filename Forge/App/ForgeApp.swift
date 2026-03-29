import SwiftUI
import SwiftData
import ForgeKit

@main
struct ForgeApp: App {
    @State private var appState = AppState()
    @State private var blockEngine = BlockEngine()
    @State private var bypassDetector = BypassDetector()
    @State private var appDelegate = ForgeAppDelegate()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay {
                    if appState.isBypassActive {
                        BypassSheetView(
                            appState: appState,
                            blockEngine: blockEngine
                        )
                    }
                }
                .environment(appState)
                .environment(blockEngine)
                .task {
                    let defaults = UserDefaults(suiteName: "group.app.forge") ?? .standard
                    if let persisted = BypassPersistence.restore(from: defaults) {
                        appState.isBypassActive = true
                        appState.bypassStage = persisted.stage
                        if persisted.stage == .cooldown,
                           let cooldownEnd = defaults.object(forKey: BypassPersistence.Keys.cooldownEndDate) as? Date {
                            appState.cooldownEndDate = cooldownEnd
                        }
                    }
                    bypassDetector.startMonitoring(appState: appState)
                    appDelegate.appState = appState
                    NSApplication.shared.delegate = appDelegate
                }
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Command Palette") {
                    appState.showingCommandPalette.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    appState.selectedSidebarItem = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .modelContainer(for: [
            BlockProfile.self,
            BlockSession.self,
            BlockSchedule.self
        ])

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .environment(blockEngine)
        } label: {
            Label(
                "Forge",
                systemImage: appState.isBlockActive
                    ? "flame.fill" : "flame"
            )
        }
        .menuBarExtraStyle(.window)
    }
}
