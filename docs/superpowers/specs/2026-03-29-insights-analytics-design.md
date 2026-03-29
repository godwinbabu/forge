# Phase 5c: Insights & Analytics

**Date:** 2026-03-29
**Status:** Approved
**Scope:** AnalyticsService, InsightsView with Swift Charts, sidebar wiring. Blocked attempt XPC callback wiring deferred.

---

## Goal

Users can view focus time trends, most-blocked sites, session counts, and streaks through an Insights tab with Swift Charts visualizations. An `AnalyticsService` aggregates `BlockSession` data from SwiftData.

---

## Scope Decisions

**Included:**
- AnalyticsService: aggregate sessions by day/week/month, calculate streaks, compute stats
- InsightsView: focus time area chart, most-blocked sites bar chart, streak counter, total stats
- Sidebar "Insights" tab
- Week/month toggle on charts

**Deferred:**
- XPC callback wiring (`ForgeAppCallbackProtocol.flowBlocked`) for real-time per-domain tracking — requires extension modifications and buffering. The `blockedAttemptCount` on `BlockSession` is already populated by `BlockEngine` and is sufficient for aggregate insights.
- Streak calendar (GitHub contribution-graph style) — complex custom view, deferred to polish phase
- Year view toggle — week/month is sufficient for v1

---

## Architecture

### AnalyticsService (ForgeKit)

Pure logic, testable without SwiftData. Takes arrays of session data and returns aggregated results.

```swift
public struct SessionSummary: Sendable {
    public let date: Date
    public let focusMinutes: Int
    public let sessionCount: Int
    public let blockedAttempts: Int
}

public struct InsightsData: Sendable {
    public let dailySummaries: [SessionSummary]
    public let totalFocusMinutes: Int
    public let totalSessions: Int
    public let totalBlockedAttempts: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let topBlockedDomains: [(domain: String, count: Int)]
}

public enum AnalyticsAggregator {
    public static func aggregate(sessions: [SessionInput], from startDate: Date, to endDate: Date) -> InsightsData
}
```

`SessionInput` is a plain struct matching `BlockSession` fields — avoids SwiftData dependency in ForgeKit.

### InsightsView (Forge)

SwiftUI view with:
- **Period picker:** Segmented control (Week / Month)
- **Focus time chart:** Area chart showing daily focus minutes over the selected period (Swift Charts)
- **Stats row:** Total focus time, sessions, blocked attempts, current streak
- **Top blocked sites:** Horizontal bar chart of most-blocked domains (top 5)

The view fetches `BlockSession` records from SwiftData, maps them to `SessionInput`, and passes to `AnalyticsAggregator`.

### Streak Calculation

A streak is consecutive calendar days where at least one completed session exists (trigger != "bypass"). Today counts if there's a session. Yesterday must have a session for the streak to continue. Bypass-only days break the streak.

---

## Files

### Create

| File | Purpose |
|------|---------|
| `ForgeKit/AnalyticsAggregator.swift` | Pure aggregation logic: daily summaries, streaks, top domains |
| `Forge/Views/Insights/InsightsView.swift` | Main insights view with charts and stats |
| `Forge/Views/Insights/FocusTimeChart.swift` | Swift Charts area chart for daily focus time |
| `Forge/Views/Insights/TopDomainsChart.swift` | Swift Charts horizontal bar chart for top blocked domains |
| `ForgeTests/AnalyticsAggregatorTests.swift` | Aggregation, streak, and domain ranking tests |

### Modify

| File | Change |
|------|--------|
| `Forge/App/AppState.swift` | Add `insights` to `SidebarItem` |
| `Forge/App/ContentView.swift` | Wire `InsightsView` to sidebar |
| `Forge/Services/AnalyticsService.swift` | Replace stub with thin wrapper that fetches from SwiftData and calls aggregator |

---

## Testing

**Unit tests (ForgeKit scheme):**
- Empty sessions → zero totals, zero streak
- Single session → 1 day streak, correct focus minutes
- Multiple sessions same day → aggregated into one daily summary
- Consecutive days → streak calculated correctly
- Gap in days → streak resets
- Bypass sessions don't count toward streak
- Top domains ranked by frequency, capped at requested count
- Week vs month date range filtering
