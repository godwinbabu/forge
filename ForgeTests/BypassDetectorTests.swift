import Testing
import Foundation
@testable import ForgeKit

@Suite("BypassDetector Tests")
struct BypassDetectorTests {

    @Test func persistsBypassStateToUserDefaults() {
        let defaults = UserDefaults(suiteName: "test.bypass.detector.\(UUID().uuidString)")!
        BypassPersistence.save(stage: .reenablePrompt, to: defaults)

        #expect(defaults.bool(forKey: BypassPersistence.Keys.bypassActive) == true)
        #expect(defaults.integer(forKey: BypassPersistence.Keys.bypassStage) == BypassStage.reenablePrompt.rawValue)
    }

    @Test func restoresBypassStateFromUserDefaults() {
        let defaults = UserDefaults(suiteName: "test.bypass.detector.\(UUID().uuidString)")!
        defaults.set(true, forKey: BypassPersistence.Keys.bypassActive)
        defaults.set(BypassStage.typingChallenge.rawValue, forKey: BypassPersistence.Keys.bypassStage)

        let state = BypassPersistence.restore(from: defaults)
        #expect(state?.stage == .typingChallenge)
    }

    @Test func returnsNilWhenNoPersistedState() {
        let defaults = UserDefaults(suiteName: "test.bypass.detector.\(UUID().uuidString)")!
        let state = BypassPersistence.restore(from: defaults)
        #expect(state == nil)
    }

    @Test func clearsBypassState() {
        let defaults = UserDefaults(suiteName: "test.bypass.detector.\(UUID().uuidString)")!
        BypassPersistence.save(stage: .cooldown, to: defaults)
        BypassPersistence.clear(from: defaults)

        #expect(defaults.bool(forKey: BypassPersistence.Keys.bypassActive) == false)
    }

    @Test func persistsCooldownEndDate() {
        let defaults = UserDefaults(suiteName: "test.bypass.detector.\(UUID().uuidString)")!
        let endDate = Date().addingTimeInterval(600)
        BypassPersistence.saveCooldownEnd(endDate, to: defaults)

        let restored = defaults.object(forKey: BypassPersistence.Keys.cooldownEndDate) as? Date
        #expect(restored != nil)
        #expect(abs(restored!.timeIntervalSince(endDate)) < 1)
    }
}
