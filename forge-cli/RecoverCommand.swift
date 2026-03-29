import Foundation
import ArgumentParser

struct RecoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "recover",
        abstract: "Emergency recovery — clear Forge block state"
    )

    @Flag(name: .long, help: "Skip confirmation prompt")
    var force = false

    func run() throws {
        if !force {
            print("This will clear all active block state.")
            print("Type 'yes' to confirm:")
            guard readLine()?.lowercased() == "yes" else {
                print("Cancelled.")
                throw ExitCode.success
            }
        }

        // Clear shared block state
        if let defaults = UserDefaults(suiteName: "group.app.forge") {
            defaults.set(false, forKey: "isBlockActive")
            defaults.removeObject(forKey: "blockEndDate")
            defaults.removeObject(forKey: "activeProfileName")
            defaults.set(0, forKey: "blockedAttemptCount")

            // Clear bypass state
            defaults.set(false, forKey: "forge.bypass.active")
            defaults.removeObject(forKey: "forge.bypass.stage")
            defaults.removeObject(forKey: "forge.bypass.cooldownEndDate")

            defaults.synchronize()
            print("✓ Cleared block state from shared defaults")
        } else {
            print("✗ Could not access App Group defaults")
        }

        print("")
        print("To fully disable Forge's network extension:")
        print("  1. Open System Settings → General → Login Items & Extensions")
        print("  2. Find 'Network Extensions' and disable Forge")
        print("")
        print("Recovery complete.")
    }
}
