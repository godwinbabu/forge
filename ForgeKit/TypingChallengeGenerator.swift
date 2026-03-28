import Foundation

public struct TypingChallengeGenerator: Sendable {

    private static let templates: [String] = [
        "I am choosing to end my focus session early with {TIME} remaining on the clock.",
        "I am ending this block with {TIME} left on my timer. I understand my streak will reset.",
        "I want to stop focusing right now. I had {TIME} of deep work remaining on my timer.",
        "I am giving up on this focus session. There were {TIME} left before it would have ended.",
        "I am choosing distraction over deep focus. I had {TIME} of commitment time remaining.",
        "I decided to quit this session early. My block had {TIME} remaining when I stopped it.",
        "I am breaking my own commitment to focused work. I still had {TIME} left in this session.",
        "I want to end my focus block now. I originally committed to {TIME} more of focused work.",
    ]

    public init() {}

    public func generate(remainingTime: String) -> String {
        let template = Self.templates.randomElement()!
        return template.replacingOccurrences(of: "{TIME}", with: remainingTime)
    }
}
