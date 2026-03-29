import AppIntents

struct ExtendBlockIntent: AppIntent {
    static let title: LocalizedStringResource = "Extend Forge Block"
    static let description = IntentDescription("Extend the current focus block")

    @Parameter(title: "Additional minutes", default: 30)
    var additionalMinutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Extend block by \(\.$additionalMinutes) minutes")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let defaults = UserDefaults(suiteName: "group.app.forge")
        let isActive = defaults?.bool(forKey: "isBlockActive") ?? false

        guard isActive else {
            return .result(value: "No active block to extend.")
        }

        // Extending requires BlockEngine to update the network extension configuration.
        // For v1, direct the user to the app.
        return .result(value: "Open Forge to extend your block. Shortcut-based extension coming in a future update.")
    }
}
