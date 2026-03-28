import Foundation

public struct CooldownState: Sendable {
    public let endDate: Date
    public static let duration: TimeInterval = 600 // 10 minutes

    public init(endDate: Date) {
        self.endDate = endDate
    }

    public static func newCooldownEndDate() -> Date {
        Date().addingTimeInterval(duration)
    }

    public var isExpired: Bool {
        Date() >= endDate
    }

    public var remainingSeconds: Int {
        max(0, Int(endDate.timeIntervalSinceNow))
    }
}
