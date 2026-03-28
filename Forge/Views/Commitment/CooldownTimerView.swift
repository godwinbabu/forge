import SwiftUI
import ForgeKit

struct CooldownTimerView: View {
    let cooldownEndDate: Date
    let onBypassed: () -> Void
    let onCancel: () -> Void

    @State private var remainingSeconds: Int = 600
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "hourglass")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
                .symbolEffect(.pulse, options: .repeating)

            Text("Take a moment")
                .font(.title.bold())

            Text(formattedTime)
                .font(.system(size: 64, weight: .light, design: .monospaced))
                .monospacedDigit()

            Text("What do you actually need right now?")
                .font(.title3)
                .foregroundStyle(.secondary)
                .italic()

            ProgressView(value: progress)
                .frame(maxWidth: 400)
                .tint(.purple)

            Button("Cancel — continue my session", role: .cancel) {
                onCancel()
            }
            .font(.callout)

            Spacer()
        }
        .padding(48)
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var progress: Double {
        1.0 - (Double(remainingSeconds) / CooldownState.duration)
    }

    private func startTimer() {
        remainingSeconds = max(0, Int(cooldownEndDate.timeIntervalSinceNow))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let remaining = Int(cooldownEndDate.timeIntervalSinceNow)
            if remaining <= 0 {
                timer?.invalidate()
                remainingSeconds = 0
                onBypassed()
            } else {
                remainingSeconds = remaining
            }
        }
    }
}
