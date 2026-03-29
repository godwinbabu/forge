import Foundation
import SwiftData

@Model
final class BlockSchedule {
    @Attribute(.unique) var id: UUID
    var profileID: UUID
    var profileName: String
    var weekdays: [Int]         // 1=Sunday ... 7=Saturday
    var startHour: Int          // 0-23
    var startMinute: Int        // 0-59
    var endHour: Int
    var endMinute: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        profileID: UUID,
        profileName: String,
        weekdays: [Int] = [],
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 17,
        endMinute: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.profileID = profileID
        self.profileName = profileName
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = isEnabled
        self.createdAt = .now
        self.updatedAt = .now
    }
}
