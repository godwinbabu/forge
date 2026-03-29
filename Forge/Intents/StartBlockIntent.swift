import AppIntents

struct StartBlockIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Forge Block"
    static let description = IntentDescription("Start a focus block session")

    @Parameter(title: "Profile")
    var profile: ProfileEntity?

    @Parameter(title: "Duration (minutes)", default: 60)
    var durationMinutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$durationMinutes) minute block with \(\.$profile)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // BlockEngine requires the app's process context to activate network extensions.
        // For v1, direct the user to the app.
        return .result(value: "Open Forge to start a block. Shortcut-based activation coming in a future update.")
    }
}
