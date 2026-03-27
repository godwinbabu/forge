import WidgetKit

struct ForgeTimelineEntry: TimelineEntry {
    let date: Date
    let isBlockActive: Bool
    let blockEndDate: Date?
    let profileName: String?
}

struct ForgeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForgeTimelineEntry {
        ForgeTimelineEntry(date: .now, isBlockActive: false, blockEndDate: nil, profileName: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ForgeTimelineEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ForgeTimelineEntry>) -> Void) {
        let entry = ForgeTimelineEntry(date: .now, isBlockActive: false, blockEndDate: nil, profileName: nil)
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
        completion(timeline)
    }
}
