import SwiftUI
import SwiftData
import ForgeKit

struct CommandAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

struct CommandPaletteView: View {
    @Binding var isPresented: Bool
    @Environment(AppState.self) private var appState
    @Query(sort: \BlockProfile.sortOrder) private var profiles: [BlockProfile]

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search commands...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit { executeSelected() }
            }
            .padding(12)

            Divider()

            // Results
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(filteredActions.enumerated()), id: \.element.id) { index, action in
                        HStack(spacing: 10) {
                            Image(systemName: action.icon)
                                .frame(width: 20)
                                .foregroundStyle(.secondary)
                            Text(action.title)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(index == selectedIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            action.action()
                            isPresented = false
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 500)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
        .onAppear {
            isSearchFocused = true
            selectedIndex = 0
        }
        .onChange(of: searchText) { selectedIndex = 0 }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredActions.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
    }

    private var allActions: [CommandAction] {
        var actions: [CommandAction] = []

        // Navigation
        actions.append(CommandAction(title: "Go to Dashboard", icon: "gauge.with.dots.needle.bottom.50percent") {
            appState.selectedSidebarItem = .dashboard
        })
        actions.append(CommandAction(title: "Go to Profiles", icon: "person.crop.rectangle.stack") {
            appState.selectedSidebarItem = .profiles
        })
        actions.append(CommandAction(title: "Go to Schedules", icon: "calendar") {
            appState.selectedSidebarItem = .schedules
        })
        actions.append(CommandAction(title: "Go to Insights", icon: "chart.bar.fill") {
            appState.selectedSidebarItem = .insights
        })
        actions.append(CommandAction(title: "Go to Settings", icon: "gear") {
            appState.selectedSidebarItem = .settings
        })

        // Profile quick-start
        for profile in profiles {
            actions.append(CommandAction(
                title: "Start \(profile.name)",
                icon: profile.iconName
            ) {
                appState.selectedSidebarItem = .dashboard
                // Navigate to dashboard where user can start the profile
            })
        }

        return actions
    }

    private var filteredActions: [CommandAction] {
        guard !searchText.isEmpty else { return allActions }
        let matches = FuzzyMatcher.match(
            query: searchText,
            candidates: allActions.map(\.title)
        )
        let matchedTitles = Set(matches.map(\.text))
        return allActions.filter { matchedTitles.contains($0.title) }
    }

    private func executeSelected() {
        let actions = filteredActions
        guard selectedIndex < actions.count else { return }
        actions[selectedIndex].action()
        isPresented = false
    }
}
