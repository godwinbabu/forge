import NetworkExtension

final class FilterManagerService {
    func loadAndActivate() async throws {
        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()
        if !manager.isEnabled {
            manager.isEnabled = true
            let providerConfig = NEFilterProviderConfiguration()
            providerConfig.filterPackets = false
            providerConfig.filterSockets = true
            manager.providerConfiguration = providerConfig
            manager.localizedDescription = "Forge Content Filter"
            try await manager.saveToPreferences()
        }
    }

    var isEnabled: Bool { NEFilterManager.shared().isEnabled }

    func startMonitoring(onChange: @escaping (Bool) -> Void) {
        NotificationCenter.default.addObserver(
            forName: .NEFilterConfigurationDidChange,
            object: nil, queue: .main
        ) { _ in onChange(NEFilterManager.shared().isEnabled) }
    }
}
