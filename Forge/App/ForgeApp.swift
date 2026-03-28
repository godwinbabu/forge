import SwiftUI

@main
struct ForgeApp: App {
    var body: some Scene {
        MenuBarExtra("Forge", systemImage: "flame.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)

        WindowGroup {
            ContentView()
        }
    }
}
