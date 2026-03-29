import Foundation

public struct ScheduleDraft: Sendable {
    public var profileID: UUID?
    public var profileName: String
    public var weekdays: [Int]
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var isEnabled: Bool

    public init(
        profileID: UUID? = nil, profileName: String = "",
        weekdays: [Int] = [],
        startHour: Int = 9, startMinute: Int = 0,
        endHour: Int = 17, endMinute: Int = 0,
        isEnabled: Bool = true
    ) {
        self.profileID = profileID
        self.profileName = profileName
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = isEnabled
    }

    public static var defaults: ScheduleDraft { ScheduleDraft() }
}
