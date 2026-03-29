import Foundation

public enum ScheduleMatch {
    public static func isActive(
        weekday: Int, hour: Int, minute: Int,
        scheduleWeekdays: [Int],
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int
    ) -> Bool {
        guard !scheduleWeekdays.isEmpty else { return false }

        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        if startMinutes < endMinutes {
            // Same-day window
            return scheduleWeekdays.contains(weekday)
                && currentMinutes >= startMinutes
                && currentMinutes < endMinutes
        } else {
            // Overnight window
            let previousWeekday = weekday == 1 ? 7 : weekday - 1
            if currentMinutes >= startMinutes && scheduleWeekdays.contains(weekday) {
                return true
            }
            if currentMinutes < endMinutes && scheduleWeekdays.contains(previousWeekday) {
                return true
            }
            return false
        }
    }
}
