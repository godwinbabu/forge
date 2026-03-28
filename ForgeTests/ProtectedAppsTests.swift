import Testing
@testable import ForgeKit

@Suite("ProtectedApps Tests")
struct ProtectedAppsTests {

    @Test func containsAllRequiredBundleIDs() {
        let required = [
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.SystemSettings",
            "com.apple.loginwindow",
            "com.apple.SecurityAgent",
            "com.apple.Terminal",
            "app.forge.Forge",
            "app.forge.Forge.ForgeFilterExtension",
        ]
        for bundleID in required {
            #expect(
                ProtectedApps.allBundleIDs.contains(bundleID),
                "\(bundleID) should be in protected apps"
            )
        }
    }

    @Test func isProtectedReturnsTrueForProtectedApp() {
        #expect(ProtectedApps.isProtected("com.apple.finder"))
        #expect(ProtectedApps.isProtected("com.apple.Terminal"))
        #expect(ProtectedApps.isProtected("app.forge.Forge"))
    }

    @Test func isProtectedReturnsFalseForNonProtectedApp() {
        #expect(!ProtectedApps.isProtected("com.google.Chrome"))
        #expect(!ProtectedApps.isProtected("com.apple.Safari"))
        #expect(!ProtectedApps.isProtected("org.mozilla.firefox"))
    }
}
