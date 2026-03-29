import Foundation

enum BrowserCacheClearer {
    private static let cachePaths = [
        "Library/Caches/Google/Chrome",
        "Library/Caches/com.apple.Safari",
        "Library/Caches/Firefox",
        "Library/Caches/com.operasoftware.Opera",
    ]

    static func clearCaches() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default

        for relativePath in cachePaths {
            let cacheURL = home.appendingPathComponent(relativePath)
            guard fm.fileExists(atPath: cacheURL.path) else { continue }
            try? fm.removeItem(at: cacheURL)
        }

        // Flush DNS cache
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
        task.arguments = ["-flushcache"]
        try? task.run()
        task.waitUntilExit()
    }
}
