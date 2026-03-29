import SwiftUI
import SwiftData
import ForgeKit

struct ProfileEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingProfile: BlockProfile?
    @State private var draft: ProfileDraft
    @State private var showingAppPicker = false
    @State private var profileColor: Color

    init(profile: BlockProfile? = nil) {
        self.existingProfile = profile
        if let profile {
            _draft = State(initialValue: ProfileDraft(
                name: profile.name,
                iconName: profile.iconName,
                colorHex: profile.colorHex,
                isBlocklist: profile.isBlocklist,
                domains: profile.domains,
                appBundleIDs: profile.appBundleIDs,
                expandSubdomains: profile.expandSubdomains,
                allowLocalNetwork: profile.allowLocalNetwork,
                clearBrowserCaches: profile.clearBrowserCaches
            ))
            _profileColor = State(initialValue: Color(hex: profile.colorHex) ?? .blue)
        } else {
            let defaults = ProfileDraft.defaults
            _draft = State(initialValue: defaults)
            _profileColor = State(initialValue: Color(hex: defaults.colorHex) ?? .blue)
        }
    }

    var body: some View {
        Form {
            // Identity
            Section("Identity") {
                TextField("Profile Name", text: $draft.name)
                    .textFieldStyle(.roundedBorder)

                IconPickerView(selectedIcon: $draft.iconName)

                ColorPicker("Color", selection: $profileColor, supportsOpacity: false)
                    .onChange(of: profileColor) {
                        draft.colorHex = profileColor.hexString
                    }
            }

            // Mode
            Section("Blocking Mode") {
                Picker("Mode", selection: $draft.isBlocklist) {
                    Text("Blocklist").tag(true)
                    Text("Allowlist").tag(false)
                }
                .pickerStyle(.segmented)
            }

            // Domains
            DomainListEditor(domains: $draft.domains)

            // Apps
            Section("Apps") {
                if draft.appBundleIDs.isEmpty {
                    Text("No apps selected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draft.appBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                draft.appBundleIDs.removeAll { $0 == bundleID }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button("Choose Apps...") {
                    showingAppPicker = true
                }
            }

            // Options
            Section("Options") {
                Toggle("Expand common subdomains (www, m, mobile, api)", isOn: $draft.expandSubdomains)
                Toggle("Allow local network traffic", isOn: $draft.allowLocalNetwork)
                Toggle("Clear browser caches on block start", isOn: $draft.clearBrowserCaches)
            }

            // Import preset
            Section("Import Preset") {
                let presets = PresetProfileLoader.loadBundled()
                if !presets.isEmpty {
                    ForEach(presets, id: \.name) { preset in
                        Button(preset.name) {
                            draft.domains = preset.domains
                            draft.appBundleIDs = preset.appBundleIDs
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(selectedBundleIDs: $draft.appBundleIDs)
        }
    }

    private func save() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existingProfile {
            existingProfile.name = trimmedName
            existingProfile.iconName = draft.iconName
            existingProfile.colorHex = draft.colorHex
            existingProfile.isBlocklist = draft.isBlocklist
            existingProfile.domains = DomainValidator.validateList(draft.domains)
            existingProfile.appBundleIDs = draft.appBundleIDs
            existingProfile.expandSubdomains = draft.expandSubdomains
            existingProfile.allowLocalNetwork = draft.allowLocalNetwork
            existingProfile.clearBrowserCaches = draft.clearBrowserCaches
            existingProfile.updatedAt = .now
        } else {
            let profile = BlockProfile(
                name: trimmedName,
                iconName: draft.iconName,
                colorHex: draft.colorHex,
                isBlocklist: draft.isBlocklist,
                domains: DomainValidator.validateList(draft.domains),
                appBundleIDs: draft.appBundleIDs,
                expandSubdomains: draft.expandSubdomains,
                allowLocalNetwork: draft.allowLocalNetwork,
                clearBrowserCaches: draft.clearBrowserCaches
            )
            modelContext.insert(profile)
        }

        dismiss()
    }
}
