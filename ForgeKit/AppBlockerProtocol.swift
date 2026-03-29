import Foundation

public enum ProtectedApps {
    public static let allBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.systempreferences",
        "com.apple.SystemSettings",
        "com.apple.loginwindow",
        "com.apple.SecurityAgent",
        "com.apple.Terminal",
        "app.forge.Forge",
        "app.forge.Forge.ForgeFilterExtension",
    ]

    public static func isProtected(_ bundleID: String) -> Bool {
        allBundleIDs.contains(bundleID)
    }
}

public enum BundleIDResolver {
    /// Walk up from executable path to find .app bundle, read CFBundleIdentifier.
    public static func bundleID(forExecutableAt path: String) -> String? {
        var url = URL(fileURLWithPath: path)
        while url.path != "/" {
            if url.pathExtension == "app" {
                return Bundle(url: url)?.bundleIdentifier
            }
            url = url.deletingLastPathComponent()
        }
        return nil
    }
}
