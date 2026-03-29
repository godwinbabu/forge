import ArgumentParser
import Foundation

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
        let defaults = UserDefaults(suiteName: "group.app.forge")
        let isActive = defaults?.bool(forKey: "isBlockActive") ?? false

        guard isActive else {
            print("No active block.")
            return
        }

        let profileName = defaults?.string(forKey: "activeProfileName") ?? "Unknown"
        if let endDate = defaults?.object(forKey: "blockEndDate") as? Date {
            let remaining = endDate.timeIntervalSinceNow
            if remaining > 0 {
                let minutes = Int(remaining / 60)
                let hours = minutes / 60
                let mins = minutes % 60
                print("\(profileName) — \(hours)h \(mins)m remaining")
            } else {
                print("\(profileName) — block has expired")
            }
        } else {
            print("\(profileName) — active")
        }
    }
}
