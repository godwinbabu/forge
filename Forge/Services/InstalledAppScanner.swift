import Foundation

struct InstalledApp: Identifiable, Hashable {
    let id: String          // bundle ID
    let displayName: String
    let path: URL
}

enum InstalledAppScanner {
    private static let searchDirectories = [
        "/Applications",
        "/System/Applications",
    ]

    static func scan() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        var seenBundleIDs = Set<String>()
        let fileManager = FileManager.default

        for directory in searchDirectories {
            let dirURL = URL(fileURLWithPath: directory)
            guard let enumerator = fileManager.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                enumerator.skipDescendants()

                guard let bundle = Bundle(url: fileURL),
                      let bundleID = bundle.bundleIdentifier,
                      !seenBundleIDs.contains(bundleID) else { continue }

                let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? fileURL.deletingPathExtension().lastPathComponent

                seenBundleIDs.insert(bundleID)
                apps.append(InstalledApp(
                    id: bundleID,
                    displayName: displayName,
                    path: fileURL
                ))
            }
        }

        return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
