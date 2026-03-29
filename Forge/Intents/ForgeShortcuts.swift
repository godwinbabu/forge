import AppIntents

struct ForgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetBlockStatusIntent(),
            phrases: [
                "Check \(.applicationName) status",
                "Is \(.applicationName) blocking?",
                "Am I in a \(.applicationName) focus session?",
            ],
            shortTitle: "Block Status",
            systemImageName: "flame.fill"
        )
    }
}
