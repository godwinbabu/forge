import SwiftUI

struct CountdownTimerView: View {
    let endDate: Date
    @State private var timeRemaining: TimeInterval = 0

    var body: some View {
        Text(formattedTime)
            .font(.system(
                size: 64,
                weight: .bold,
                design: .monospaced
            ))
            .onAppear { updateTime() }
            .onReceive(
                Timer.publish(every: 1, on: .main, in: .common)
                    .autoconnect()
            ) { _ in
                updateTime()
            }
    }

    private func updateTime() {
        timeRemaining = max(0, endDate.timeIntervalSinceNow)
    }

    private var formattedTime: String {
        let total = Int(timeRemaining)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(
                format: "%d:%02d:%02d",
                hours, minutes, seconds
            )
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
