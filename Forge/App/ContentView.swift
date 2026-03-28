import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            List(
                SidebarItem.allCases,
                selection: $state.selectedSidebarItem
            ) { item in
                Label(item.rawValue, systemImage: item.icon)
            }
            .navigationTitle("Forge")
        } detail: {
            switch appState.selectedSidebarItem {
            case .dashboard:
                DashboardView()
            case .profiles:
                ProfileListView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
