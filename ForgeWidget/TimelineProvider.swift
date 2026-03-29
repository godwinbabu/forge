import WidgetKit

struct ForgeTimelineEntry: TimelineEntry {
    let date: Date
    let isBlockActive: Bool
    let blockEndDate: Date?
    let profileName: String?
    let blockedAttemptCount: Int
}

struct ForgeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForgeTimelineEntry {
        ForgeTimelineEntry(
            date: .now,
            isBlockActive: false,
            blockEndDate: nil,
            profileName: nil,
            blockedAttemptCount: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ForgeTimelineEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ForgeTimelineEntry>) -> Void) {
        let entry = currentEntry()
        let refreshDate: Date
        if entry.isBlockActive, let endDate = entry.blockEndDate {
            // Refresh every minute during active block, and at block end
            refreshDate = min(Date().addingTimeInterval(60), endDate)
        } else {
            // 5 minutes when idle
            refreshDate = Date().addingTimeInterval(300)
        }
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func currentEntry() -> ForgeTimelineEntry {
        let defaults = UserDefaults(suiteName: "group.app.forge")
        let isActive = defaults?.bool(forKey: "isBlockActive") ?? false
        let endDate = defaults?.object(forKey: "blockEndDate") as? Date
        let profileName = defaults?.string(forKey: "activeProfileName")
        let blocked = defaults?.integer(forKey: "blockedAttemptCount") ?? 0

        return ForgeTimelineEntry(
            date: .now,
            isBlockActive: isActive,
            blockEndDate: endDate,
            profileName: profileName,
            blockedAttemptCount: blocked
        )
    }
}
