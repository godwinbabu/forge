import SwiftUI

struct DurationPickerView: View {
    let profile: BlockProfile
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var durationMinutes: Double = 60

    var body: some View {
        VStack(spacing: 24) {
            Text("Start \(profile.name)")
                .font(.title2.weight(.semibold))

            VStack(spacing: 8) {
                Text(formattedDuration)
                    .font(.system(
                        .largeTitle,
                        design: .rounded,
                        weight: .bold
                    ))
                    .contentTransition(.numericText())

                Slider(
                    value: $durationMinutes,
                    in: 15...480,
                    step: 15
                )
                .padding(.horizontal)

                HStack {
                    Text("15 min")
                    Spacer()
                    Text("8 hours")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }

            Button("Start Block") {
                Task {
                    try? await blockEngine.startBlock(
                        profile: profile,
                        duration: durationMinutes * 60,
                        dohServerIPs: [],
                        appState: appState,
                        modelContext: modelContext
                    )
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 360)
    }

    private var formattedDuration: String {
        let hours = Int(durationMinutes) / 60
        let mins = Int(durationMinutes) % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }
}
