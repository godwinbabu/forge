import ArgumentParser

@main
struct ForgeCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "forge",
        abstract: "Forge — block distractions from the command line",
        version: "1.0.0",
        subcommands: [StatusCommand.self, RecoverCommand.self]
    )
}

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show current block status"
    )

    func run() throws {
        print("No active block.")
    }
}
