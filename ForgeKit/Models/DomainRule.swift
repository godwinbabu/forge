import Foundation

public enum DomainRule: Codable, Sendable, Hashable {
    case exact(String)
    case wildcard(String)
    case cidr(String, Int)
    case portSpecific(String, Int)
}
