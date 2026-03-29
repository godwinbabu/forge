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
            ForgeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Forge Status")
        .description("Shows your current focus block status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ForgeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ForgeTimelineEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}
