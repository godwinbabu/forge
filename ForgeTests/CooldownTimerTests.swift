import Testing
import Foundation
@testable import ForgeKit

@Suite("CooldownTimer Tests")
struct CooldownTimerTests {

    @Test func cooldownDurationIsTenMinutes() {
        let endDate = CooldownState.newCooldownEndDate()
        let interval = endDate.timeIntervalSinceNow
        #expect(interval > 599 && interval <= 600, "Cooldown should be ~600 seconds, got \(interval)")
    }

    @Test func cooldownNotExpiredBeforeTenMinutes() {
        let endDate = Date().addingTimeInterval(300)
        let state = CooldownState(endDate: endDate)
        #expect(!state.isExpired)
    }

    @Test func cooldownExpiredAfterEndDate() {
        let endDate = Date().addingTimeInterval(-1)
        let state = CooldownState(endDate: endDate)
        #expect(state.isExpired)
    }

    @Test func remainingSecondsCalculation() {
        let endDate = Date().addingTimeInterval(120)
        let state = CooldownState(endDate: endDate)
        let remaining = state.remainingSeconds
        #expect(remaining >= 119 && remaining <= 120)
    }
}
