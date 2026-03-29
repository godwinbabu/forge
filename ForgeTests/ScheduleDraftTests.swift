import Foundation
import Testing
@testable import ForgeKit

@Suite("ScheduleDraft Tests")
struct ScheduleDraftTests {
    @Test func defaultsHaveExpectedValues() {
        let draft = ScheduleDraft.defaults
        #expect(draft.profileID == nil)
        #expect(draft.profileName == "")
        #expect(draft.weekdays.isEmpty)
        #expect(draft.startHour == 9)
        #expect(draft.startMinute == 0)
        #expect(draft.endHour == 17)
        #expect(draft.endMinute == 0)
        #expect(draft.isEnabled == true)
    }

    @Test func initWithAllFields() {
        let id = UUID()
        let draft = ScheduleDraft(
            profileID: id, profileName: "Work",
            weekdays: [2, 3, 4, 5, 6],
            startHour: 8, startMinute: 30,
            endHour: 16, endMinute: 45,
            isEnabled: false
        )
        #expect(draft.profileID == id)
        #expect(draft.profileName == "Work")
        #expect(draft.weekdays == [2, 3, 4, 5, 6])
        #expect(draft.startHour == 8)
        #expect(draft.startMinute == 30)
        #expect(draft.endHour == 16)
        #expect(draft.endMinute == 45)
        #expect(draft.isEnabled == false)
    }
}
