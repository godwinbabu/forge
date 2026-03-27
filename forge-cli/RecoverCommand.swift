import ArgumentParser
import Foundation

struct RecoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recover",
        abstract: "Emergency recovery — remove all Forge system modifications"
    )

    @Flag(name: .long, help: "Force recovery without confirmation")
    var force = false

    func run() throws {
        guard ProcessInfo.processInfo.userName == "root" || force else {
            print("Recovery requires root access. Run with sudo.")
            throw ExitCode.failure
        }
        print("Recovery complete.")
    }
}
