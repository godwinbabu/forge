import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine

    var body: some View {
        VStack(spacing: 0) {
            if appState.isBlockActive {
                activeContent
            } else {
                readyContent
            }

            Divider()

            Button("Open Forge...") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(
                    where: { $0.canBecomeMain }
                ) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Button("Quit Forge") {
                if !appState.isBlockActive {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .disabled(appState.isBlockActive)
        }
        .frame(width: 280)
    }

    private var activeContent: some View {
        VStack(spacing: 12) {
            HStack {
                if let icon = appState.activeProfileIcon {
                    Image(systemName: icon)
                        .foregroundStyle(.tint)
                }
                Text(appState.activeProfileName ?? "Active Block")
                    .font(.headline)
                Spacer()
            }

            if let endDate = appState.blockEndDate {
                CountdownTimerView(endDate: endDate)
                    .font(.system(
                        size: 28,
                        weight: .bold,
                        design: .monospaced
                    ))
            }

            Text("\(appState.blockedAttemptCount) blocked")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var readyContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Ready to focus")
                .font(.headline)
            Text("Open Forge to start a block")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
