import SwiftUI
import Charts
import ForgeKit

struct FocusTimeChart: View {
    let summaries: [SessionSummary]

    var body: some View {
        Chart(summaries) { summary in
            AreaMark(
                x: .value("Date", summary.date, unit: .day),
                y: .value("Minutes", summary.focusMinutes)
            )
            .foregroundStyle(.blue.gradient)
        }
        .chartYAxisLabel("Focus (min)")
        .frame(height: 200)
    }
}
