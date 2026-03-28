import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isBlockActive {
            ActiveBlockView()
        } else {
            ReadyView()
        }
    }
}

struct ReadyView: View {
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BlockProfile.sortOrder) private var profiles: [BlockProfile]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Ready to focus")
                    .font(.largeTitle.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if profiles.isEmpty {
                    ContentUnavailableView(
                        "No Profiles",
                        systemImage: "plus.circle",
                        description: Text("Create a profile to get started")
                    )
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200))],
                        spacing: 16
                    ) {
                        ForEach(profiles) { profile in
                            ProfileCardView(profile: profile)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
