import Foundation
import SwiftData

@Model
final class BlockSession {
    @Attribute(.unique) var id: UUID
    var profileID: UUID?
    var profileName: String
    var startDate: Date
    var endDate: Date
    var actualEndDate: Date?
    var domains: [String]
    var isBlocklist: Bool
    var blockedAttemptCount: Int
    var wasExtended: Bool
    var trigger: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        profileID: UUID? = nil,
        profileName: String,
        startDate: Date,
        endDate: Date,
        domains: [String] = [],
        isBlocklist: Bool = true,
        blockedAttemptCount: Int = 0,
        wasExtended: Bool = false,
        trigger: String = "manual"
    ) {
        self.id = id
        self.profileID = profileID
        self.profileName = profileName
        self.startDate = startDate
        self.endDate = endDate
        self.domains = domains
        self.isBlocklist = isBlocklist
        self.blockedAttemptCount = blockedAttemptCount
        self.wasExtended = wasExtended
        self.trigger = trigger
        self.createdAt = .now
    }
}
