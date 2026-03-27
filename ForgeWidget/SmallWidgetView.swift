import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: ForgeTimelineEntry

    var body: some View {
        VStack {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
            Text("Ready")
                .font(.headline)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
