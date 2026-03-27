import SwiftUI
import WidgetKit

@main
struct ForgeWidgetBundle: WidgetBundle {
    var body: some Widget {
        ForgeStatusWidget()
    }
}

struct ForgeStatusWidget: Widget {
    let kind = "ForgeStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ForgeTimelineProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Forge Status")
        .description("Shows your current focus block status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
