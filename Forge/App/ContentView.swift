import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @Environment(\.modelContext) private var modelContext
    @State private var scheduleEvaluator = ScheduleEvaluator()

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
            case .schedules:
                ScheduleListView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .task {
            scheduleEvaluator.start(
                appState: appState,
                blockEngine: blockEngine,
                modelContext: modelContext
            )
        }
    }
}
