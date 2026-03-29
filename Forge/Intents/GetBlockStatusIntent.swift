import AppIntents

struct GetBlockStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Forge Block Status"
    static let description = IntentDescription("Check if a focus block is currently active")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let defaults = UserDefaults(suiteName: "group.app.forge")
        let isActive = defaults?.bool(forKey: "isBlockActive") ?? false

        guard isActive else {
            return .result(value: "No active block.")
        }

        let profileName = defaults?.string(forKey: "activeProfileName") ?? "Unknown"

        if let endDate = defaults?.object(forKey: "blockEndDate") as? Date {
            let remaining = endDate.timeIntervalSinceNow
            if remaining > 0 {
                let minutes = Int(remaining / 60)
                let hours = minutes / 60
                let mins = minutes % 60
                if hours > 0 {
                    return .result(value: "\(profileName) active — \(hours)h \(mins)m remaining")
                }
                return .result(value: "\(profileName) active — \(mins)m remaining")
            }
        }

        return .result(value: "\(profileName) active")
    }
}
