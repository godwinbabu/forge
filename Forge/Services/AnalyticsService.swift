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
