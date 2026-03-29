import Testing
@testable import ForgeKit

@Suite("ScheduleMatch Tests")
struct ScheduleMatchTests {
    @Test func insideSameDayWindow() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 12, minute: 0,
            scheduleWeekdays: [2, 3, 4, 5, 6],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        #expect(result == true)
    }

    @Test func outsideSameDayWindow() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 18, minute: 0,
            scheduleWeekdays: [2, 3, 4, 5, 6],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        #expect(result == false)
    }

    @Test func wrongWeekday() {
        let result = ScheduleMatch.isActive(
            weekday: 1, hour: 12, minute: 0,
            scheduleWeekdays: [2, 3, 4, 5, 6],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        #expect(result == false)
    }

    @Test func insideOvernightWindowLateNight() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 23, minute: 0,
            scheduleWeekdays: [2],
            startHour: 22, startMinute: 0, endHour: 6, endMinute: 0
        )
        #expect(result == true)
    }

    @Test func insideOvernightWindowEarlyMorning() {
        // Tuesday 2 AM — schedule started Monday 10 PM
        // Previous weekday (Monday=2) is in weekdays
        let result = ScheduleMatch.isActive(
            weekday: 3, hour: 2, minute: 0,
            scheduleWeekdays: [2],
            startHour: 22, startMinute: 0, endHour: 6, endMinute: 0
        )
        #expect(result == true)
    }

    @Test func outsideOvernightWindow() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 7, minute: 0,
            scheduleWeekdays: [2],
            startHour: 22, startMinute: 0, endHour: 6, endMinute: 0
        )
        #expect(result == false)
    }

    @Test func exactlyAtStartTime() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 9, minute: 0,
            scheduleWeekdays: [2],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        #expect(result == true)
    }

    @Test func exactlyAtEndTime() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 17, minute: 0,
            scheduleWeekdays: [2],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        #expect(result == false)
    }

    @Test func emptyWeekdaysNeverActive() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 12, minute: 0,
            scheduleWeekdays: [],
            startHour: 9, startMinute: 0, endHour: 17, endMinute: 0
        )
        #expect(result == false)
    }
}
