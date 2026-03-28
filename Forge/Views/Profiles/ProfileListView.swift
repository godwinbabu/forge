import SwiftUI
import SwiftData

struct ProfileListView: View {
    @Query(sort: \BlockProfile.sortOrder) private var profiles: [BlockProfile]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(profiles) { profile in
                HStack(spacing: 12) {
                    Image(systemName: profile.iconName)
                        .font(.title2)
                        .foregroundStyle(
                            Color(hex: profile.colorHex) ?? .accentColor
                        )
                        .frame(width: 32)

                    VStack(alignment: .leading) {
                        Text(profile.name)
                            .font(.headline)
                        Text(
                            "\(profile.domains.count) sites"
                            + " \u{00B7} "
                            + (profile.isBlocklist
                                ? "Blocklist" : "Allowlist")
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteProfiles)
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem {
                Button(
                    "Seed Presets",
                    systemImage: "arrow.down.circle"
                ) {
                    seedPresetProfiles()
                }
            }
        }
        .overlay {
            if profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "shield.slash",
                    description: Text(
                        "Tap 'Seed Presets' to load built-in profiles"
                    )
                )
            }
        }
    }

    private func deleteProfiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(profiles[index])
        }
    }

    private func seedPresetProfiles() {
        let presets = PresetProfileLoader.loadBundled()
        for (index, preset) in presets.enumerated() {
            let profile = BlockProfile(
                name: preset.name,
                iconName: preset.iconName,
                colorHex: preset.colorHex,
                isBlocklist: preset.isBlocklist,
                domains: preset.domains,
                appBundleIDs: preset.appBundleIDs,
                expandSubdomains: preset.expandSubdomains,
                allowLocalNetwork: preset.allowLocalNetwork,
                clearBrowserCaches: preset.clearBrowserCaches,
                sortOrder: index
            )
            modelContext.insert(profile)
        }
    }
}
