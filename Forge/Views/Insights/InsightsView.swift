import SwiftUI
import SwiftData
import ForgeKit

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var period: InsightsPeriod = .week
    @State private var insights: InsightsData = .empty

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Picker("Period", selection: $period) {
                    ForEach(InsightsPeriod.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                // Stats row
                HStack(spacing: 24) {
                    statCard("Focus Time", value: formatMinutes(insights.totalFocusMinutes), icon: "clock.fill")
                    statCard("Sessions", value: "\(insights.totalSessions)", icon: "flame.fill")
                    statCard("Blocked", value: "\(insights.totalBlockedAttempts)", icon: "hand.raised.fill")
                    statCard("Streak", value: "\(insights.currentStreak) day\(insights.currentStreak == 1 ? "" : "s")", icon: "star.fill")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus Time").font(.headline)
                    FocusTimeChart(summaries: insights.dailySummaries)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Most Blocked Sites").font(.headline)
                    TopDomainsChart(domains: insights.topBlockedDomains)
                }

                if insights.longestStreak > 0 {
                    Text("Longest streak: \(insights.longestStreak) day\(insights.longestStreak == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Insights")
        .task { loadInsights() }
        .onChange(of: period) { loadInsights() }
    }

    private func loadInsights() {
        let service = AnalyticsService(modelContext: modelContext)
        insights = service.getInsights(period: period)
    }

    private func statCard(_ title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
}
