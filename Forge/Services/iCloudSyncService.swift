import Foundation
import SwiftData
import ForgeKit

@MainActor
final class ICloudSyncService {
    private let store = NSUbiquitousKeyValueStore.default
    private var observer: NSObjectProtocol?

    func start(modelContext: ModelContext) {
        // Sync local -> iCloud
        syncToCloud(modelContext: modelContext)

        // Listen for remote changes
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncFromCloud(modelContext: modelContext)
            }
        }

        store.synchronize()
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    func syncToCloud(modelContext: ModelContext) {
        let profileDescriptor = FetchDescriptor<BlockProfile>(sortBy: [SortDescriptor(\.sortOrder)])
        if let profiles = try? modelContext.fetch(profileDescriptor) {
            for profile in profiles {
                let data = PresetProfileData(
                    name: profile.name,
                    iconName: profile.iconName,
                    colorHex: profile.colorHex,
                    isBlocklist: profile.isBlocklist,
                    domains: profile.domains,
                    appBundleIDs: profile.appBundleIDs,
                    expandSubdomains: profile.expandSubdomains,
                    allowLocalNetwork: profile.allowLocalNetwork,
                    clearBrowserCaches: profile.clearBrowserCaches
                )
                if let encoded = try? JSONEncoder().encode(data) {
                    store.set(encoded, forKey: "profile-\(profile.id.uuidString)")
                }
                // Store updatedAt for conflict resolution
                store.set(profile.updatedAt.timeIntervalSince1970, forKey: "profile-ts-\(profile.id.uuidString)")
            }
        }

        store.synchronize()
    }

    func syncFromCloud(modelContext: ModelContext) {
        let allKeys = store.dictionaryRepresentation.keys
        let profileKeys = allKeys.filter { $0.hasPrefix("profile-") && !$0.hasPrefix("profile-ts-") }

        for key in profileKeys {
            guard let data = store.data(forKey: key),
                  let preset = try? JSONDecoder().decode(PresetProfileData.self, from: data) else { continue }

            let uuidString = String(key.dropFirst("profile-".count))
            guard let uuid = UUID(uuidString: uuidString) else { continue }

            let cloudTimestamp = store.double(forKey: "profile-ts-\(uuidString)")

            // Check if local profile exists
            let descriptor = FetchDescriptor<BlockProfile>(
                predicate: #Predicate<BlockProfile> { profile in
                    profile.id == uuid
                }
            )

            if let existing = try? modelContext.fetch(descriptor).first {
                // Last-writer-wins: only update if cloud is newer
                if cloudTimestamp > existing.updatedAt.timeIntervalSince1970 {
                    existing.name = preset.name
                    existing.iconName = preset.iconName
                    existing.colorHex = preset.colorHex
                    existing.isBlocklist = preset.isBlocklist
                    existing.domains = preset.domains
                    existing.appBundleIDs = preset.appBundleIDs
                    existing.expandSubdomains = preset.expandSubdomains
                    existing.allowLocalNetwork = preset.allowLocalNetwork
                    existing.clearBrowserCaches = preset.clearBrowserCaches
                    existing.updatedAt = Date(timeIntervalSince1970: cloudTimestamp)
                }
            } else {
                // New profile from cloud
                let profile = BlockProfile(
                    id: uuid,
                    name: preset.name,
                    iconName: preset.iconName,
                    colorHex: preset.colorHex,
                    isBlocklist: preset.isBlocklist,
                    domains: preset.domains,
                    appBundleIDs: preset.appBundleIDs,
                    expandSubdomains: preset.expandSubdomains,
                    allowLocalNetwork: preset.allowLocalNetwork,
                    clearBrowserCaches: preset.clearBrowserCaches
                )
                profile.updatedAt = Date(timeIntervalSince1970: cloudTimestamp)
                modelContext.insert(profile)
            }
        }
    }
}
