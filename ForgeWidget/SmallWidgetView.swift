import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: ForgeTimelineEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.isBlockActive ? "flame.fill" : "flame")
                .font(.title)
                .foregroundStyle(entry.isBlockActive ? .orange : .secondary)

            if entry.isBlockActive, let endDate = entry.blockEndDate {
                Text(entry.profileName ?? "Focus")
                    .font(.caption.bold())
                Text(endDate, style: .timer)
                    .font(.title3.monospacedDigit())
                    .multilineTextAlignment(.center)
            } else {
                Text("Ready to focus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
