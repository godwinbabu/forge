import Foundation

public enum BypassStage: Int, Sendable {
    case reenablePrompt = 0
    case typingChallenge = 1
    case cooldown = 2
}

public struct PersistedBypassState: Sendable {
    public let stage: BypassStage
}

public enum BypassPersistence {
    public enum Keys {
        public static let bypassActive = "forge.bypass.active"
        public static let bypassStage = "forge.bypass.stage"
        public static let cooldownEndDate = "forge.bypass.cooldownEndDate"
    }

    public static func save(stage: BypassStage, to defaults: UserDefaults) {
        defaults.set(true, forKey: Keys.bypassActive)
        defaults.set(stage.rawValue, forKey: Keys.bypassStage)
    }

    public static func restore(from defaults: UserDefaults) -> PersistedBypassState? {
        guard defaults.bool(forKey: Keys.bypassActive) else { return nil }
        let rawStage = defaults.integer(forKey: Keys.bypassStage)
        let stage = BypassStage(rawValue: rawStage) ?? .reenablePrompt
        return PersistedBypassState(stage: stage)
    }

    public static func clear(from defaults: UserDefaults) {
        defaults.set(false, forKey: Keys.bypassActive)
        defaults.removeObject(forKey: Keys.bypassStage)
        defaults.removeObject(forKey: Keys.cooldownEndDate)
    }

    public static func saveCooldownEnd(_ date: Date, to defaults: UserDefaults) {
        defaults.set(date, forKey: Keys.cooldownEndDate)
    }
}
