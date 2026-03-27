import Foundation
import SwiftData

@Model
final class BlockSchedule {
    var profileName: String
    var weekdays: [Int]
    var startTime: Date
    var endTime: Date
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        profileName: String,
        weekdays: [Int] = [],
        startTime: Date = .now,
        endTime: Date = .now,
        isEnabled: Bool = true
    ) {
        self.profileName = profileName
        self.weekdays = weekdays
        self.startTime = startTime
        self.endTime = endTime
        self.isEnabled = isEnabled
        self.createdAt = .now
        self.updatedAt = .now
    }
}
