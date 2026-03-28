import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: ForgeTimelineEntry

    var body: some View {
        HStack {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
            VStack(alignment: .leading) {
                Text("Forge")
                    .font(.headline)
                Text("No active block")
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
