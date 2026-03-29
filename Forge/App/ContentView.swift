import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @Environment(\.modelContext) private var modelContext
    @State private var scheduleEvaluator = ScheduleEvaluator()
    @State private var iCloudSync = ICloudSyncService()

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
            case .insights:
                InsightsView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .overlay {
            if appState.showingCommandPalette {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            appState.showingCommandPalette = false
                        }

                    CommandPaletteView(isPresented: $state.showingCommandPalette)
                        .padding(.top, 100)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .task {
            scheduleEvaluator.start(
                appState: appState,
                blockEngine: blockEngine,
                modelContext: modelContext
            )
            iCloudSync.start(modelContext: modelContext)
        }
    }
}
