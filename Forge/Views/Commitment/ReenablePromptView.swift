import SwiftUI

struct ReenablePromptView: View {
    let blockEndDate: Date
    let blockedAttemptCount: Int
    let onRequestQuit: () -> Void

    @State private var showQuitButton = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "shield.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Your Focus Extension Was Disabled")
                .font(.title.bold())

            VStack(spacing: 8) {
                Label(timeRemainingText, systemImage: "clock")
                if blockedAttemptCount > 0 {
                    Label(
                        "\(blockedAttemptCount) distractions blocked so far",
                        systemImage: "hand.raised.fill"
                    )
                }
            }
            .font(.title3)
            .foregroundStyle(.secondary)

            Text("You committed to this focus session. Re-enable the extension to continue.")
                .font(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Button {
                openExtensionSettings()
            } label: {
                Label("Re-enable Forge", systemImage: "arrow.uturn.backward")
                    .font(.title3.bold())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)

            if showQuitButton {
                Button("I want to quit", role: .destructive) {
                    onRequestQuit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(48)
        .task {
            try? await Task.sleep(for: .seconds(30))
            withAnimation(.easeIn(duration: 0.5)) {
                showQuitButton = true
            }
        }
    }

    private var timeRemainingText: String {
        let remaining = blockEndDate.timeIntervalSinceNow
        guard remaining > 0 else { return "Block has ended" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) minute\(minutes == 1 ? "" : "s") remaining"
        }
        return "\(minutes) minute\(minutes == 1 ? "" : "s") remaining"
    }

    private func openExtensionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ContentFilter") {
            NSWorkspace.shared.open(url)
        }
    }
}
