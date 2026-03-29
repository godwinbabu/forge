import Foundation
import Testing
@testable import ForgeKit

@Suite("AnalyticsAggregator Tests")
struct AnalyticsAggregatorTests {

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeSession(
        start: Date,
        end: Date,
        domains: [String] = ["reddit.com"],
        blockedAttemptCount: Int = 0,
        trigger: String = "manual"
    ) -> SessionInput {
        SessionInput(
            startDate: start,
            endDate: end,
            domains: domains,
            blockedAttemptCount: blockedAttemptCount,
            trigger: trigger
        )
    }

    // MARK: - Tests

    @Test func emptySessionsReturnsZeros() {
        let result = AnalyticsAggregator.aggregate(
            sessions: [],
            from: date(2026, 3, 1),
            to: date(2026, 3, 31)
        )

        #expect(result.totalFocusMinutes == 0)
        #expect(result.totalSessions == 0)
        #expect(result.totalBlockedAttempts == 0)
        #expect(result.currentStreak == 0)
        #expect(result.longestStreak == 0)
        #expect(result.topBlockedDomains.isEmpty)
        #expect(result.dailySummaries.isEmpty)
    }

    @Test func singleSessionAggregation() {
        let session = makeSession(
            start: date(2026, 3, 15, 10),
            end: date(2026, 3, 15, 12),
            blockedAttemptCount: 5
        )

        let result = AnalyticsAggregator.aggregate(
            sessions: [session],
            from: date(2026, 3, 1),
            to: date(2026, 4, 1)
        )

        #expect(result.totalFocusMinutes == 120)
        #expect(result.totalSessions == 1)
        #expect(result.totalBlockedAttempts == 5)
        #expect(result.dailySummaries.count == 1)

        let summary = result.dailySummaries[0]
        #expect(summary.focusMinutes == 120)
        #expect(summary.sessionCount == 1)
        #expect(summary.blockedAttempts == 5)
    }

    @Test func multipleSessionsSameDayAggregated() {
        let session1 = makeSession(
            start: date(2026, 3, 15, 9),
            end: date(2026, 3, 15, 10),
            blockedAttemptCount: 3
        )
        let session2 = makeSession(
            start: date(2026, 3, 15, 14),
            end: date(2026, 3, 15, 16),
            blockedAttemptCount: 7
        )

        let result = AnalyticsAggregator.aggregate(
            sessions: [session1, session2],
            from: date(2026, 3, 1),
            to: date(2026, 4, 1)
        )

        #expect(result.totalFocusMinutes == 180)
        #expect(result.totalSessions == 2)
        #expect(result.totalBlockedAttempts == 10)
        #expect(result.dailySummaries.count == 1)

        let summary = result.dailySummaries[0]
        #expect(summary.focusMinutes == 180)
        #expect(summary.sessionCount == 2)
    }

    @Test func consecutiveDaysStreak() {
        // Use relative dates ending today so current streak is valid
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sessions = (-2...0).map { offset -> SessionInput in
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day)!
            let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
            return makeSession(start: start, end: end)
        }

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: calendar.date(byAdding: .day, value: -30, to: today)!,
            to: calendar.date(byAdding: .day, value: 1, to: today)!
        )

        #expect(result.currentStreak == 3)
        #expect(result.longestStreak == 3)
    }

    @Test func gapBreaksStreak() {
        // Today, yesterday (gap), 3 days ago, 4 days ago
        // So: day-4, day-3 (streak of 2), gap on day-2, then today (streak of 1)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func dayAt(_ offset: Int) -> (start: Date, end: Date) {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day)!
            let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
            return (start, end)
        }

        let d4 = dayAt(-4)
        let d3 = dayAt(-3)
        let d0 = dayAt(0)

        let sessions = [
            makeSession(start: d4.start, end: d4.end),
            makeSession(start: d3.start, end: d3.end),
            makeSession(start: d0.start, end: d0.end),
        ]

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: calendar.date(byAdding: .day, value: -30, to: today)!,
            to: calendar.date(byAdding: .day, value: 1, to: today)!
        )

        #expect(result.currentStreak == 1)
        #expect(result.longestStreak == 2)
    }

    @Test func bypassSessionsDoNotCountForStreak() {
        // Yesterday: normal, Today: bypass only — current streak should not include today
        // Day before yesterday: normal
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func dayAt(_ offset: Int) -> (start: Date, end: Date) {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day)!
            let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
            return (start, end)
        }

        let d2 = dayAt(-2)
        let d1 = dayAt(-1)
        let d0 = dayAt(0)

        let sessions = [
            makeSession(start: d2.start, end: d2.end),
            makeSession(start: d1.start, end: d1.end, trigger: "bypass"),
            makeSession(start: d0.start, end: d0.end),
        ]

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: calendar.date(byAdding: .day, value: -30, to: today)!,
            to: calendar.date(byAdding: .day, value: 1, to: today)!
        )

        // Day -1 is bypass-only so breaks the streak
        #expect(result.currentStreak == 1)
        #expect(result.longestStreak == 1)
    }

    @Test func topBlockedDomainsRankedByFrequency() {
        let sessions = [
            makeSession(
                start: date(2026, 3, 15, 10),
                end: date(2026, 3, 15, 11),
                domains: ["reddit.com", "twitter.com", "youtube.com"]
            ),
            makeSession(
                start: date(2026, 3, 16, 10),
                end: date(2026, 3, 16, 11),
                domains: ["reddit.com", "twitter.com"]
            ),
            makeSession(
                start: date(2026, 3, 17, 10),
                end: date(2026, 3, 17, 11),
                domains: ["reddit.com"]
            ),
        ]

        let result = AnalyticsAggregator.aggregate(
            sessions: sessions,
            from: date(2026, 3, 1),
            to: date(2026, 4, 1),
            topDomainCount: 2
        )

        #expect(result.topBlockedDomains.count == 2)
        #expect(result.topBlockedDomains[0].domain == "reddit.com")
        #expect(result.topBlockedDomains[0].count == 3)
        #expect(result.topBlockedDomains[1].domain == "twitter.com")
        #expect(result.topBlockedDomains[1].count == 2)
    }

    @Test func sessionsFilteredByDateRange() {
        let insideSession = makeSession(
            start: date(2026, 3, 15, 10),
            end: date(2026, 3, 15, 12),
            blockedAttemptCount: 5
        )
        let outsideSession = makeSession(
            start: date(2026, 2, 15, 10),
            end: date(2026, 2, 15, 12),
            blockedAttemptCount: 10
        )

        let result = AnalyticsAggregator.aggregate(
            sessions: [insideSession, outsideSession],
            from: date(2026, 3, 1),
            to: date(2026, 4, 1)
        )

        #expect(result.totalSessions == 1)
        #expect(result.totalBlockedAttempts == 5)
    }
}
