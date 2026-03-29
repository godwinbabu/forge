# Insights & Analytics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Insights tab with Swift Charts showing focus time trends, top blocked sites, session stats, and streaks aggregated from BlockSession data.

**Architecture:** `AnalyticsAggregator` (ForgeKit) is a pure function that takes session inputs and returns aggregated data. `InsightsView` fetches from SwiftData, maps to inputs, and renders charts. `AnalyticsService` is a thin SwiftData wrapper.

**Tech Stack:** SwiftUI, Swift Charts, SwiftData, ForgeKit, Swift Testing

---

## File Structure

| File | Responsibility |
|------|---------------|
| `ForgeKit/AnalyticsAggregator.swift` (create) | Pure aggregation: daily summaries, streaks, top domains |
| `Forge/Views/Insights/InsightsView.swift` (create) | Main view with period picker and stats |
| `Forge/Views/Insights/FocusTimeChart.swift` (create) | Area chart for daily focus minutes |
| `Forge/Views/Insights/TopDomainsChart.swift` (create) | Horizontal bar chart for top blocked domains |
| `Forge/Services/AnalyticsService.swift` (modify) | SwiftData fetch + aggregator call |
| `Forge/App/AppState.swift` (modify) | Add insights to SidebarItem |
| `Forge/App/ContentView.swift` (modify) | Wire InsightsView |
| `ForgeTests/AnalyticsAggregatorTests.swift` (create) | Aggregation and streak tests |

---

### Task 1: AnalyticsAggregator (TDD)

**Files:**
- Create: `ForgeTests/AnalyticsAggregatorTests.swift`
- Create: `ForgeKit/AnalyticsAggregator.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ForgeTests/AnalyticsAggregatorTests.swift
import Testing
import Foundation
@testable import ForgeKit

@Suite("AnalyticsAggregator Tests")
struct AnalyticsAggregatorTests {

    private func makeSession(
        startDate: Date,
        endDate: Date,
        domains: [String] = [],
        blockedAttempts: Int = 0,
        trigger: String = "manual"
    ) -> SessionInput {
        SessionInput(
            startDate: startDate,
            endDate: endDate,
            domains: domains,
            blockedAttemptCount: blockedAttempts,
            trigger: trigger
        )
    }

    private var calendar: Calendar { Calendar.current }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func emptySessionsReturnsZeros() {
        let result = AnalyticsAggregator.aggregate(
            sessions: [],
            from: date(2026, 3, 1),
            to: date(2026, 3, 7)
        )
        #expect(result.totalFocusMinutes == 0)
        #expect(result.totalSessions == 0)
        #expect(result.totalBlockedAttempts == 0)
        #expect(result.currentStreak == 0)
        #expect(result.longestStreak == 0)
        #expect(result.topBlockedDomains.isEmpty)
    }

    @Test func singleSessionAggregation() {
        let start = date(2026, 3, 15, 9)
        let end = date(2026, 3, 15, 11) // 2 hours
        let sessions = [makeSession(startDate: start, endDate: end, blockedAttempts: 5)]

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: date(2026, 3, 15),
            to: date(2026, 3, 16)
        )
        #expect(result.totalFocusMinutes == 120)
        #expect(result.totalSessions == 1)
        #expect(result.totalBlockedAttempts == 5)
        #expect(result.dailySummaries.count == 1)
        #expect(result.dailySummaries.first?.focusMinutes == 120)
    }

    @Test func multipleSessionsSameDayAggregated() {
        let s1 = makeSession(startDate: date(2026, 3, 15, 9), endDate: date(2026, 3, 15, 11), blockedAttempts: 3)
        let s2 = makeSession(startDate: date(2026, 3, 15, 14), endDate: date(2026, 3, 15, 16), blockedAttempts: 7)

        let result = AnalyticsAggregator.aggregate(
            sessions: [s1, s2],
            from: date(2026, 3, 15),
            to: date(2026, 3, 16)
        )
        #expect(result.totalFocusMinutes == 240)
        #expect(result.totalSessions == 2)
        #expect(result.totalBlockedAttempts == 10)
        #expect(result.dailySummaries.count == 1)
        #expect(result.dailySummaries.first?.focusMinutes == 240)
    }

    @Test func consecutiveDaysStreak() {
        let sessions = [
            makeSession(startDate: date(2026, 3, 13, 9), endDate: date(2026, 3, 13, 10)),
            makeSession(startDate: date(2026, 3, 14, 9), endDate: date(2026, 3, 14, 10)),
            makeSession(startDate: date(2026, 3, 15, 9), endDate: date(2026, 3, 15, 10)),
        ]

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: date(2026, 3, 10),
            to: date(2026, 3, 16)
        )
        #expect(result.currentStreak == 3)
        #expect(result.longestStreak == 3)
    }

    @Test func gapBreaksStreak() {
        let sessions = [
            makeSession(startDate: date(2026, 3, 13, 9), endDate: date(2026, 3, 13, 10)),
            makeSession(startDate: date(2026, 3, 14, 9), endDate: date(2026, 3, 14, 10)),
            // gap on March 15
            makeSession(startDate: date(2026, 3, 16, 9), endDate: date(2026, 3, 16, 10)),
        ]

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: date(2026, 3, 10),
            to: date(2026, 3, 17)
        )
        #expect(result.currentStreak == 1)
        #expect(result.longestStreak == 2)
    }

    @Test func bypassSessionsDoNotCountForStreak() {
        let sessions = [
            makeSession(startDate: date(2026, 3, 14, 9), endDate: date(2026, 3, 14, 10)),
            makeSession(startDate: date(2026, 3, 15, 9), endDate: date(2026, 3, 15, 10), trigger: "bypass"),
            makeSession(startDate: date(2026, 3, 16, 9), endDate: date(2026, 3, 16, 10)),
        ]

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: date(2026, 3, 10),
            to: date(2026, 3, 17)
        )
        // March 15 only has bypass → streak broken
        #expect(result.currentStreak == 1)
        #expect(result.longestStreak == 1)
    }

    @Test func topBlockedDomainsRankedByFrequency() {
        let sessions = [
            makeSession(startDate: date(2026, 3, 15, 9), endDate: date(2026, 3, 15, 10),
                        domains: ["reddit.com", "twitter.com", "reddit.com"]),
            makeSession(startDate: date(2026, 3, 16, 9), endDate: date(2026, 3, 16, 10),
                        domains: ["reddit.com", "youtube.com"]),
        ]

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: date(2026, 3, 15),
            to: date(2026, 3, 17),
            topDomainCount: 3
        )
        #expect(result.topBlockedDomains.count == 3)
        #expect(result.topBlockedDomains.first?.domain == "reddit.com")
    }

    @Test func sessionsFilteredByDateRange() {
        let sessions = [
            makeSession(startDate: date(2026, 3, 10, 9), endDate: date(2026, 3, 10, 10)), // outside
            makeSession(startDate: date(2026, 3, 15, 9), endDate: date(2026, 3, 15, 10)), // inside
        ]

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: date(2026, 3, 14),
            to: date(2026, 3, 16)
        )
        #expect(result.totalSessions == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/AnalyticsAggregatorTests 2>&1 | tail -20`

- [ ] **Step 3: Implement AnalyticsAggregator**

```swift
// ForgeKit/AnalyticsAggregator.swift
import Foundation

public struct SessionInput: Sendable {
    public let startDate: Date
    public let endDate: Date
    public let domains: [String]
    public let blockedAttemptCount: Int
    public let trigger: String

    public init(startDate: Date, endDate: Date, domains: [String], blockedAttemptCount: Int, trigger: String) {
        self.startDate = startDate
        self.endDate = endDate
        self.domains = domains
        self.blockedAttemptCount = blockedAttemptCount
        self.trigger = trigger
    }
}

public struct SessionSummary: Sendable, Identifiable {
    public let id: Date
    public let date: Date
    public let focusMinutes: Int
    public let sessionCount: Int
    public let blockedAttempts: Int

    public init(date: Date, focusMinutes: Int, sessionCount: Int, blockedAttempts: Int) {
        self.id = date
        self.date = date
        self.focusMinutes = focusMinutes
        self.sessionCount = sessionCount
        self.blockedAttempts = blockedAttempts
    }
}

public struct InsightsData: Sendable {
    public let dailySummaries: [SessionSummary]
    public let totalFocusMinutes: Int
    public let totalSessions: Int
    public let totalBlockedAttempts: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let topBlockedDomains: [(domain: String, count: Int)]

    public static var empty: InsightsData {
        InsightsData(
            dailySummaries: [], totalFocusMinutes: 0, totalSessions: 0,
            totalBlockedAttempts: 0, currentStreak: 0, longestStreak: 0,
            topBlockedDomains: []
        )
    }

    public init(dailySummaries: [SessionSummary], totalFocusMinutes: Int, totalSessions: Int,
                totalBlockedAttempts: Int, currentStreak: Int, longestStreak: Int,
                topBlockedDomains: [(domain: String, count: Int)]) {
        self.dailySummaries = dailySummaries
        self.totalFocusMinutes = totalFocusMinutes
        self.totalSessions = totalSessions
        self.totalBlockedAttempts = totalBlockedAttempts
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.topBlockedDomains = topBlockedDomains
    }
}

public enum AnalyticsAggregator {
    public static func aggregate(
        sessions: [SessionInput],
        from startDate: Date,
        to endDate: Date,
        topDomainCount: Int = 5
    ) -> InsightsData {
        let calendar = Calendar.current

        // Filter sessions within date range
        let filtered = sessions.filter { $0.startDate >= startDate && $0.startDate < endDate }

        guard !filtered.isEmpty else { return .empty }

        // Group by calendar day
        var dailyMap: [Date: (focusMinutes: Int, sessionCount: Int, blockedAttempts: Int, hasCompleted: Bool)] = [:]
        var domainCounts: [String: Int] = [:]

        for session in filtered {
            let dayStart = calendar.startOfDay(for: session.startDate)
            let minutes = Int(session.endDate.timeIntervalSince(session.startDate) / 60)
            let isCompleted = session.trigger != "bypass"

            var entry = dailyMap[dayStart] ?? (0, 0, 0, false)
            entry.focusMinutes += max(minutes, 0)
            entry.sessionCount += 1
            entry.blockedAttempts += session.blockedAttemptCount
            if isCompleted { entry.hasCompleted = true }
            dailyMap[dayStart] = entry

            for domain in session.domains {
                domainCounts[domain, default: 0] += 1
            }
        }

        // Build daily summaries sorted by date
        let summaries = dailyMap.map { day, data in
            SessionSummary(date: day, focusMinutes: data.focusMinutes,
                           sessionCount: data.sessionCount, blockedAttempts: data.blockedAttempts)
        }.sorted { $0.date < $1.date }

        // Calculate streaks (from most recent day backwards)
        let completedDays = Set(dailyMap.filter { $0.value.hasCompleted }.map { $0.key })
        let (current, longest) = calculateStreaks(completedDays: completedDays, calendar: calendar)

        // Top domains
        let topDomains = domainCounts.sorted { $0.value > $1.value }
            .prefix(topDomainCount)
            .map { (domain: $0.key, count: $0.value) }

        let totalFocus = summaries.reduce(0) { $0 + $1.focusMinutes }
        let totalSessions = summaries.reduce(0) { $0 + $1.sessionCount }
        let totalBlocked = summaries.reduce(0) { $0 + $1.blockedAttempts }

        return InsightsData(
            dailySummaries: summaries,
            totalFocusMinutes: totalFocus,
            totalSessions: totalSessions,
            totalBlockedAttempts: totalBlocked,
            currentStreak: current,
            longestStreak: longest,
            topBlockedDomains: topDomains
        )
    }

    private static func calculateStreaks(completedDays: Set<Date>, calendar: Calendar) -> (current: Int, longest: Int) {
        guard !completedDays.isEmpty else { return (0, 0) }

        let sorted = completedDays.sorted(by: >)  // most recent first
        let today = calendar.startOfDay(for: Date())

        // Current streak: count consecutive days ending today or yesterday
        var currentStreak = 0
        var checkDate = today
        // Allow starting from today or yesterday
        if !completedDays.contains(checkDate) {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            if !completedDays.contains(checkDate) {
                currentStreak = 0
            }
        }
        if completedDays.contains(checkDate) {
            while completedDays.contains(checkDate) {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            }
        }

        // Longest streak: scan all sorted days
        var longest = 0
        var streak = 1
        let ascending = completedDays.sorted()
        for i in 1..<ascending.count {
            let prev = ascending[i - 1]
            let curr = ascending[i]
            let dayDiff = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
            if dayDiff == 1 {
                streak += 1
            } else {
                longest = max(longest, streak)
                streak = 1
            }
        }
        longest = max(longest, streak)

        return (currentStreak, longest)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/AnalyticsAggregatorTests 2>&1 | tail -20`
Expected: All 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add ForgeKit/AnalyticsAggregator.swift ForgeTests/AnalyticsAggregatorTests.swift
git commit -m "Add AnalyticsAggregator with daily summaries, streaks, and top domains"
```

---

### Task 2: AnalyticsService (SwiftData wrapper)

**Files:**
- Modify: `Forge/Services/AnalyticsService.swift`

- [ ] **Step 1: Replace the stub with SwiftData-backed service**

```swift
// Forge/Services/AnalyticsService.swift
import Foundation
import SwiftData
import ForgeKit

@MainActor
final class AnalyticsService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getInsights(period: InsightsPeriod) -> InsightsData {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        switch period {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now)!
        }

        let descriptor = FetchDescriptor<BlockSession>(
            sortBy: [SortDescriptor(\.startDate)]
        )
        guard let sessions = try? modelContext.fetch(descriptor) else {
            return .empty
        }

        let inputs = sessions.map { session in
            SessionInput(
                startDate: session.startDate,
                endDate: session.actualEndDate ?? session.endDate,
                domains: session.domains,
                blockedAttemptCount: session.blockedAttemptCount,
                trigger: session.trigger
            )
        }

        return AnalyticsAggregator.aggregate(
            sessions: inputs,
            from: startDate,
            to: now
        )
    }
}

enum InsightsPeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

- [ ] **Step 3: Commit**

```bash
git add Forge/Services/AnalyticsService.swift
git commit -m "Replace AnalyticsService stub with SwiftData-backed implementation"
```

---

### Task 3: FocusTimeChart + TopDomainsChart

**Files:**
- Create: `Forge/Views/Insights/FocusTimeChart.swift`
- Create: `Forge/Views/Insights/TopDomainsChart.swift`

- [ ] **Step 1: Create FocusTimeChart**

```swift
// Forge/Views/Insights/FocusTimeChart.swift
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
```

- [ ] **Step 2: Create TopDomainsChart**

```swift
// Forge/Views/Insights/TopDomainsChart.swift
import SwiftUI
import Charts

struct TopDomainsChart: View {
    let domains: [(domain: String, count: Int)]

    var body: some View {
        if domains.isEmpty {
            Text("No blocked domains yet")
                .foregroundStyle(.secondary)
                .frame(height: 150)
        } else {
            Chart(domains, id: \.domain) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Domain", item.domain)
                )
                .foregroundStyle(.orange.gradient)
            }
            .frame(height: CGFloat(max(domains.count, 1) * 36))
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

- [ ] **Step 4: Commit**

```bash
git add Forge/Views/Insights/FocusTimeChart.swift Forge/Views/Insights/TopDomainsChart.swift
git commit -m "Add FocusTimeChart and TopDomainsChart with Swift Charts"
```

---

### Task 4: InsightsView + Sidebar Wiring

**Files:**
- Create: `Forge/Views/Insights/InsightsView.swift`
- Modify: `Forge/App/AppState.swift`
- Modify: `Forge/App/ContentView.swift`

- [ ] **Step 1: Create InsightsView**

```swift
// Forge/Views/Insights/InsightsView.swift
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
                // Period picker
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

                // Focus time chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus Time")
                        .font(.headline)
                    FocusTimeChart(summaries: insights.dailySummaries)
                }

                // Top blocked domains
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most Blocked Sites")
                        .font(.headline)
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
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
```

- [ ] **Step 2: Add insights to SidebarItem**

In `Forge/App/AppState.swift`, add `insights` case to `SidebarItem` after `schedules`:

```swift
    case insights = "Insights"
```

Add to `icon`:

```swift
        case .insights: "chart.bar.fill"
```

- [ ] **Step 3: Wire InsightsView in ContentView**

In `Forge/App/ContentView.swift`, add after `case .schedules`:

```swift
            case .insights:
                InsightsView()
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

- [ ] **Step 5: Commit**

```bash
git add Forge/Views/Insights/InsightsView.swift Forge/App/AppState.swift Forge/App/ContentView.swift
git commit -m "Add InsightsView with stats, charts, and sidebar wiring"
```

---

### Task 5: Run All Tests and Final Build Verification

- [ ] **Step 1: Run all tests**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' 2>&1 | tail -20`

- [ ] **Step 2: Full build**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`

- [ ] **Step 3: Verify clean state**

Run: `git status`

- [ ] **Step 4: Review commits**

Run: `git log --oneline -8`
