import Foundation
import SwiftData
import ForgeKit

@MainActor
final class ScheduleEvaluator {
    private var timer: Timer?
    private let pollInterval: TimeInterval = 30.0

    func start(appState: AppState, blockEngine: BlockEngine, modelContext: ModelContext) {
        stop()
        evaluate(appState: appState, blockEngine: blockEngine, modelContext: modelContext)
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self, weak appState, weak blockEngine] _ in
            Task { @MainActor in
                guard let self, let appState, let blockEngine else { return }
                self.evaluate(appState: appState, blockEngine: blockEngine, modelContext: modelContext)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func evaluate(appState: AppState, blockEngine: BlockEngine, modelContext: ModelContext) {
        guard !appState.isBlockActive else { return }

        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        let descriptor = FetchDescriptor<BlockSchedule>(
            predicate: #Predicate<BlockSchedule> { schedule in
                schedule.isEnabled
            }
        )
        guard let schedules = try? modelContext.fetch(descriptor) else { return }

        for schedule in schedules {
            let isActive = ScheduleMatch.isActive(
                weekday: weekday, hour: hour, minute: minute,
                scheduleWeekdays: schedule.weekdays,
                startHour: schedule.startHour, startMinute: schedule.startMinute,
                endHour: schedule.endHour, endMinute: schedule.endMinute
            )

            guard isActive else { continue }

            let profileID = schedule.profileID
            let profileDescriptor = FetchDescriptor<BlockProfile>(
                predicate: #Predicate<BlockProfile> { profile in
                    profile.id == profileID
                }
            )
            guard let profile = try? modelContext.fetch(profileDescriptor).first else { continue }

            // Calculate remaining duration
            let endMinutes = schedule.endHour * 60 + schedule.endMinute
            let currentMinutes = hour * 60 + minute
            let remainingMinutes: Int
            if schedule.startHour * 60 + schedule.startMinute < endMinutes {
                remainingMinutes = endMinutes - currentMinutes
            } else {
                if currentMinutes >= schedule.startHour * 60 + schedule.startMinute {
                    remainingMinutes = (24 * 60 - currentMinutes) + endMinutes
                } else {
                    remainingMinutes = endMinutes - currentMinutes
                }
            }

            let duration = TimeInterval(max(remainingMinutes, 1) * 60)

            Task {
                try? await blockEngine.startBlock(
                    profile: profile,
                    duration: duration,
                    dohServerIPs: [],
                    appState: appState,
                    modelContext: modelContext
                )
            }

            break // Only start one block at a time
        }
    }
}
