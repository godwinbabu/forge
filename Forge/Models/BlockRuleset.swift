import Foundation

struct BlockRuleset: Codable, Sendable {
    let blockID: UUID
    let isBlocklist: Bool
    let domains: [DomainRule]
    let appBundleIDs: [String]
    let startDate: Date
    let endDate: Date
}

enum DomainRule: Codable, Sendable, Hashable {
    case exact(String)
    case wildcard(String)
    case cidr(String)
    case portSpecific(String, Int)
}
