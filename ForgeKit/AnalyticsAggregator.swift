import Foundation

// MARK: - Types

public struct SessionInput: Sendable {
    public let startDate: Date
    public let endDate: Date
    public let domains: [String]
    public let blockedAttemptCount: Int
    public let trigger: String

    public init(
        startDate: Date,
        endDate: Date,
        domains: [String],
        blockedAttemptCount: Int,
        trigger: String
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.domains = domains
        self.blockedAttemptCount = blockedAttemptCount
        self.trigger = trigger
    }
}

public struct SessionSummary: Identifiable, Sendable {
    public let date: Date
    public let focusMinutes: Int
    public let sessionCount: Int
    public let blockedAttempts: Int

    public var id: Date { date }

    public init(date: Date, focusMinutes: Int, sessionCount: Int, blockedAttempts: Int) {
        self.date = date
        self.focusMinutes = focusMinutes
        self.sessionCount = sessionCount
        self.blockedAttempts = blockedAttempts
    }
}

public struct DomainCount: Sendable {
    public let domain: String
    public let count: Int

    public init(domain: String, count: Int) {
        self.domain = domain
        self.count = count
    }
}

public struct InsightsData: Sendable {
    public let dailySummaries: [SessionSummary]
    public let totalFocusMinutes: Int
    public let totalSessions: Int
    public let totalBlockedAttempts: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let topBlockedDomains: [DomainCount]

    public init(
        dailySummaries: [SessionSummary],
        totalFocusMinutes: Int,
        totalSessions: Int,
        totalBlockedAttempts: Int,
        currentStreak: Int,
        longestStreak: Int,
        topBlockedDomains: [DomainCount]
    ) {
        self.dailySummaries = dailySummaries
        self.totalFocusMinutes = totalFocusMinutes
        self.totalSessions = totalSessions
        self.totalBlockedAttempts = totalBlockedAttempts
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.topBlockedDomains = topBlockedDomains
    }

    public static let empty = InsightsData(
        dailySummaries: [],
        totalFocusMinutes: 0,
        totalSessions: 0,
        totalBlockedAttempts: 0,
        currentStreak: 0,
        longestStreak: 0,
        topBlockedDomains: []
    )
}

// MARK: - Aggregator

public enum AnalyticsAggregator {

    public static func aggregate(
        sessions: [SessionInput],
        from: Date,
        to: Date,
        topDomainCount: Int = 10
    ) -> InsightsData {
        let calendar = Calendar.current

        // 1. Filter sessions within [from, to)
        let filtered = sessions.filter { $0.startDate >= from && $0.startDate < to }

        guard !filtered.isEmpty else { return .empty }

        // 2. Group by calendar day
        var dayGroups: [Date: [SessionInput]] = [:]
        for session in filtered {
            let day = calendar.startOfDay(for: session.startDate)
            dayGroups[day, default: []].append(session)
        }

        // 3. Build daily summaries
        let dailySummaries = dayGroups.keys.sorted().map { day -> SessionSummary in
            let daySessions = dayGroups[day]!
            let focusMinutes = daySessions.reduce(0) { total, session in
                total + Int(session.endDate.timeIntervalSince(session.startDate) / 60)
            }
            let blockedAttempts = daySessions.reduce(0) { $0 + $1.blockedAttemptCount }
            return SessionSummary(
                date: day,
                focusMinutes: focusMinutes,
                sessionCount: daySessions.count,
                blockedAttempts: blockedAttempts
            )
        }

        // 4. Totals
        let totalFocusMinutes = dailySummaries.reduce(0) { $0 + $1.focusMinutes }
        let totalSessions = dailySummaries.reduce(0) { $0 + $1.sessionCount }
        let totalBlockedAttempts = dailySummaries.reduce(0) { $0 + $1.blockedAttempts }

        // 5. Streaks — only days where at least one non-bypass session exists
        let completedDays: Set<Date> = Set(
            dayGroups.compactMap { day, sessions in
                sessions.contains(where: { $0.trigger != "bypass" }) ? day : nil
            }
        )

        let sortedCompletedDays = completedDays.sorted()
        let (currentStreak, longestStreak) = calculateStreaks(
            sortedDays: sortedCompletedDays,
            calendar: calendar
        )

        // 6. Top domains
        var domainCounts: [String: Int] = [:]
        for session in filtered {
            for domain in session.domains {
                domainCounts[domain, default: 0] += 1
            }
        }
        let topDomains = domainCounts
            .sorted { $0.value > $1.value }
            .prefix(topDomainCount)
            .map { DomainCount(domain: $0.key, count: $0.value) }

        return InsightsData(
            dailySummaries: dailySummaries,
            totalFocusMinutes: totalFocusMinutes,
            totalSessions: totalSessions,
            totalBlockedAttempts: totalBlockedAttempts,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            topBlockedDomains: topDomains
        )
    }

    // MARK: - Private

    private static func calculateStreaks(
        sortedDays: [Date],
        calendar: Calendar
    ) -> (current: Int, longest: Int) {
        guard !sortedDays.isEmpty else { return (0, 0) }

        var longestStreak = 1
        var currentRun = 1

        // Walk through sorted days to find runs of consecutive days
        for i in 1..<sortedDays.count {
            let prev = sortedDays[i - 1]
            let curr = sortedDays[i]
            if calendar.date(byAdding: .day, value: 1, to: prev) == curr {
                currentRun += 1
                longestStreak = max(longestStreak, currentRun)
            } else {
                currentRun = 1
            }
        }
        longestStreak = max(longestStreak, currentRun)

        // Current streak: must end on today or yesterday
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastDay = sortedDays.last!

        var currentStreak = 0
        if lastDay == today || lastDay == yesterday {
            currentStreak = 1
            var idx = sortedDays.count - 2
            while idx >= 0 {
                let prev = sortedDays[idx]
                let next = sortedDays[idx + 1]
                if calendar.date(byAdding: .day, value: 1, to: prev) == next {
                    currentStreak += 1
                    idx -= 1
                } else {
                    break
                }
            }
        }

        return (currentStreak, longestStreak)
    }
}
