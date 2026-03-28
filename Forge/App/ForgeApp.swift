import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    @State private var appState = AppState()
    @State private var blockEngine = BlockEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(blockEngine)
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
