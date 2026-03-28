import Foundation
import SwiftData

@Model
final class BlockSession {
    var startDate: Date
    var endDate: Date
    var profileName: String
    var domains: [String]
    var isBlocklist: Bool
    var blockedAttemptCount: Int
    var trigger: String
    var createdAt: Date

    init(
        startDate: Date,
        endDate: Date,
        profileName: String,
        domains: [String] = [],
        isBlocklist: Bool = true,
        blockedAttemptCount: Int = 0,
        trigger: String = "manual"
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.profileName = profileName
        self.domains = domains
        self.isBlocklist = isBlocklist
        self.blockedAttemptCount = blockedAttemptCount
        self.trigger = trigger
        self.createdAt = .now
    }
}
