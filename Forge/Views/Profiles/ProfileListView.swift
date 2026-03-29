import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ForgeKit

struct ProfileListView: View {
    @Query(sort: \BlockProfile.sortOrder) private var profiles: [BlockProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var editingProfile: BlockProfile?
    @State private var showingNewProfile = false
    @State private var showingDeleteConfirm = false
    @State private var profileToDelete: BlockProfile?
    @State private var importError: String?
    @State private var showingImportError = false

    var body: some View {
        List {
            ForEach(profiles) { profile in
                profileRow(profile)
            }
        }
        .navigationTitle("Profiles")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingNewProfile) {
            ProfileEditorView()
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(profile: profile)
        }
        .confirmationDialog(
            "Delete Profile?",
            isPresented: $showingDeleteConfirm,
            presenting: profileToDelete
        ) { profile in
            Button("Delete", role: .destructive) {
                modelContext.delete(profile)
            }
        } message: { profile in
            Text("Delete \"\(profile.name)\"? This cannot be undone.")
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK") {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .overlay {
            if profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "shield.slash",
                    description: Text("Tap '+' to create a profile or 'Seed Presets' for built-in profiles")
                )
            }
        }
    }

    private func profileRow(_ profile: BlockProfile) -> some View {
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
                Text(profileSubtitle(profile))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            editingProfile = profile
        }
        .contextMenu {
            Button("Export...") {
                exportProfile(profile)
            }
            Divider()
            Button("Delete", role: .destructive) {
                profileToDelete = profile
                showingDeleteConfirm = true
            }
        }
    }

    private func profileSubtitle(_ profile: BlockProfile) -> String {
        var parts = "\(profile.domains.count) sites"
        if !profile.appBundleIDs.isEmpty {
            parts += " \u{00B7} \(profile.appBundleIDs.count) apps"
        }
        parts += " \u{00B7} " + (profile.isBlocklist ? "Blocklist" : "Allowlist")
        return parts
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Button("Import", systemImage: "square.and.arrow.down") {
                importProfile()
            }
        }
        ToolbarItem {
            Button("Seed Presets", systemImage: "arrow.down.circle") {
                seedPresetProfiles()
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("New Profile", systemImage: "plus") {
                showingNewProfile = true
            }
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

    private func exportProfile(_ profile: BlockProfile) {
        let draft = ProfileDraft(
            name: profile.name,
            iconName: profile.iconName,
            colorHex: profile.colorHex,
            isBlocklist: profile.isBlocklist,
            domains: profile.domains,
            appBundleIDs: profile.appBundleIDs,
            expandSubdomains: profile.expandSubdomains,
            allowLocalNetwork: profile.allowLocalNetwork,
            clearBrowserCaches: profile.clearBrowserCaches
        )

        guard let data = try? ProfileSerializer.encode(draft) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(profile.name).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    private func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                let draft = try ProfileSerializer.decode(data)
                let profile = BlockProfile(
                    name: draft.name,
                    iconName: draft.iconName,
                    colorHex: draft.colorHex,
                    isBlocklist: draft.isBlocklist,
                    domains: draft.domains,
                    appBundleIDs: draft.appBundleIDs,
                    expandSubdomains: draft.expandSubdomains,
                    allowLocalNetwork: draft.allowLocalNetwork,
                    clearBrowserCaches: draft.clearBrowserCaches
                )
                modelContext.insert(profile)
            } catch {
                importError = error.localizedDescription
                showingImportError = true
            }
        }
    }
}
