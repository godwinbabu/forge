import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 24)

            Spacer()

            switch step {
            case 0: welcomeStep
            case 1: extensionStep
            case 2: profileStep
            case 3: firstBlockStep
            default: EmptyView()
            }

            Spacer()
        }
        .frame(minWidth: 500, minHeight: 400)
        .padding(32)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Welcome to Forge")
                .font(.largeTitle.bold())

            Text("Forge blocks distracting websites and apps during focus sessions. Once a block starts, it can't be easily undone — that's the point.")
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .foregroundStyle(.secondary)

            Button("Get Started") {
                withAnimation { step = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Step 2: Extension Approval

    @State private var extensionEnabled = false

    private var extensionStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Enable the Network Extension")
                .font(.title2.bold())

            Text("Forge needs a system extension to block websites. macOS will ask you to approve it in System Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .foregroundStyle(.secondary)

            if extensionEnabled {
                Label("Extension enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)

                Button("Continue") {
                    withAnimation { step = 2 }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ContentFilter") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Skip for now") {
                    withAnimation { step = 2 }
                }
                .foregroundStyle(.secondary)
            }
        }
        .task {
            // Poll for extension approval
            while !extensionEnabled {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    extensionEnabled = FilterManagerService().isEnabled
                }
            }
        }
    }

    // MARK: - Step 3: First Profile

    @State private var selectedPreset: String?

    private var profileStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.rectangle.stack.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            Text("Choose Your First Profile")
                .font(.title2.bold())

            Text("Pick a category of distractions to block, or skip to create your own later.")
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                presetButton("Social Media", icon: "bubble.left.fill", color: .blue)
                presetButton("News & Media", icon: "newspaper.fill", color: .orange)
                presetButton("Gaming", icon: "gamecontroller.fill", color: .green)
            }

            HStack(spacing: 16) {
                Button("Skip") {
                    withAnimation { step = 3 }
                }
                .foregroundStyle(.secondary)

                if selectedPreset != nil {
                    Button("Continue") {
                        createPresetProfile()
                        withAnimation { step = 3 }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func presetButton(_ name: String, icon: String, color: Color) -> some View {
        Button {
            selectedPreset = name
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                Text(name)
                    .font(.caption)
            }
            .frame(width: 100, height: 80)
            .background(
                selectedPreset == name ? color.opacity(0.2) : Color.secondary.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPreset == name ? color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func createPresetProfile() {
        let presets = PresetProfileLoader.loadBundled()
        guard let preset = presets.first(where: { $0.name == selectedPreset }) else { return }
        let profile = BlockProfile(
            name: preset.name,
            iconName: preset.iconName,
            colorHex: preset.colorHex,
            isBlocklist: preset.isBlocklist,
            domains: preset.domains,
            appBundleIDs: preset.appBundleIDs,
            expandSubdomains: preset.expandSubdomains,
            allowLocalNetwork: preset.allowLocalNetwork,
            clearBrowserCaches: preset.clearBrowserCaches
        )
        modelContext.insert(profile)
    }

    // MARK: - Step 4: Done

    private var firstBlockStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.largeTitle.bold())

            Text("Start a focus session from the dashboard whenever you're ready.")
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .foregroundStyle(.secondary)

            Button("Open Dashboard") {
                UserDefaults.standard.set(true, forKey: "forge.onboarding.completed")
                isComplete = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
