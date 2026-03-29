import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: ForgeTimelineEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Image(systemName: entry.isBlockActive ? "flame.fill" : "flame")
                    .font(.largeTitle)
                    .foregroundStyle(entry.isBlockActive ? .orange : .secondary)

                if entry.isBlockActive {
                    Text(entry.profileName ?? "Focus")
                        .font(.caption.bold())
                } else {
                    Text("Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80)

            if entry.isBlockActive, let endDate = entry.blockEndDate {
                VStack(alignment: .leading, spacing: 8) {
                    Text(endDate, style: .timer)
                        .font(.title2.monospacedDigit())

                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.caption)
                        Text("\(entry.blockedAttemptCount) blocked")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("No active block")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
