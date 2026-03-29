import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("forge.launchAtLogin") private var launchAtLogin = false
    @AppStorage("forge.defaultDurationMinutes") private var defaultDuration = 60.0

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch Forge at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) {
                        updateLoginItem()
                    }
            }

            Section("Blocking") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default block duration: \(Int(defaultDuration)) minutes")
                    Slider(value: $defaultDuration, in: 15...480, step: 15)
                }
            }

            Section("Recovery") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If Forge is stuck or behaving unexpectedly, you can clear all block state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Emergency Recovery", role: .destructive) {
                        performRecovery()
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                LabeledContent("Build", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Settings] Login item update failed: \(error)")
        }
    }

    private func performRecovery() {
        guard let defaults = UserDefaults(suiteName: "group.app.forge") else { return }
        defaults.set(false, forKey: "isBlockActive")
        defaults.removeObject(forKey: "blockEndDate")
        defaults.removeObject(forKey: "activeProfileName")
        defaults.set(0, forKey: "blockedAttemptCount")
        defaults.set(false, forKey: "forge.bypass.active")
        defaults.removeObject(forKey: "forge.bypass.stage")
        defaults.removeObject(forKey: "forge.bypass.cooldownEndDate")
        defaults.synchronize()
    }
}
