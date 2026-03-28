import SwiftUI

struct ActiveBlockView: View {
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @State private var showingExtend = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if let icon = appState.activeProfileIcon {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
            }

            if let name = appState.activeProfileName {
                Text(name)
                    .font(.title2.weight(.medium))
            }

            if let endDate = appState.blockEndDate {
                CountdownTimerView(endDate: endDate)
            }

            HStack(spacing: 16) {
                Button("Extend 30 min") {
                    Task {
                        try? await blockEngine.extendBlock(
                            by: 1800,
                            appState: appState
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Text("\(appState.blockedAttemptCount) blocked attempts")
                .foregroundStyle(.secondary)
                .font(.callout)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
