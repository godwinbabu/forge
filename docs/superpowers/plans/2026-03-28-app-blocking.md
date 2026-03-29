# App Blocking Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent blocked apps from launching during an active block using EndpointSecurity (kernel-level denial) with an NSWorkspace fallback for running app termination and launch observation.

**Architecture:** `EndpointSecurityBlocker` runs in the system extension, subscribing to `AUTH_EXEC` events and denying blocked bundle IDs. `WorkspaceAppBlocker` runs in the main app, terminating already-running blocked apps on block start and observing for new launches as belt-and-suspenders. Both share `ProtectedApps` constants and `BundleIDResolver` from ForgeKit.

**Tech Stack:** EndpointSecurity.framework, NSWorkspace, ForgeKit, Swift Testing

---

## File Structure

| File | Responsibility |
|------|---------------|
| `ForgeKit/AppBlockerProtocol.swift` (create) | `ProtectedApps` constants, `BundleIDResolver` utility |
| `ForgeFilterExtension/EndpointSecurityBlocker.swift` (create) | ES client lifecycle, AUTH_EXEC handling, process muting |
| `Forge/Services/WorkspaceAppBlocker.swift` (create) | NSWorkspace launch observation + running app termination |
| `ForgeFilterExtension/ExtensionXPCService.swift` (modify) | Wire ES blocker into ruleset activate/deactivate |
| `Forge/Services/BlockEngine.swift` (modify) | Wire workspace blocker into start/stop block |
| `project.yml` (modify) | Add EndpointSecurity.framework to extension |
| `ForgeTests/ProtectedAppsTests.swift` (create) | Protected apps list tests |
| `ForgeTests/BundleIDResolverTests.swift` (create) | Bundle ID resolution tests |

---

### Task 1: ProtectedApps Constants + BundleIDResolver

**Files:**
- Create: `ForgeTests/ProtectedAppsTests.swift`
- Create: `ForgeTests/BundleIDResolverTests.swift`
- Create: `ForgeKit/AppBlockerProtocol.swift`

- [ ] **Step 1: Write failing tests for ProtectedApps**

```swift
// ForgeTests/ProtectedAppsTests.swift
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
```

- [ ] **Step 2: Write failing tests for BundleIDResolver**

```swift
// ForgeTests/BundleIDResolverTests.swift
import Testing
import Foundation
@testable import ForgeKit

@Suite("BundleIDResolver Tests")
struct BundleIDResolverTests {

    @Test func resolvesFinderBundleID() {
        let path = "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"
        let bundleID = BundleIDResolver.bundleID(forExecutableAt: path)
        #expect(bundleID == "com.apple.finder")
    }

    @Test func resolvesFromAppPath() {
        // Safari is reliably at this path on macOS
        let path = "/Applications/Safari.app/Contents/MacOS/Safari"
        let bundleID = BundleIDResolver.bundleID(forExecutableAt: path)
        #expect(bundleID == "com.apple.Safari")
    }

    @Test func returnsNilForNonAppExecutable() {
        let path = "/usr/bin/ls"
        let bundleID = BundleIDResolver.bundleID(forExecutableAt: path)
        #expect(bundleID == nil)
    }

    @Test func returnsNilForNonexistentPath() {
        let path = "/nonexistent/path/App.app/Contents/MacOS/binary"
        let bundleID = BundleIDResolver.bundleID(forExecutableAt: path)
        #expect(bundleID == nil)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/ProtectedAppsTests -only-testing:ForgeTests/BundleIDResolverTests 2>&1 | tail -20`
Expected: FAIL — types not defined

- [ ] **Step 4: Implement ProtectedApps and BundleIDResolver**

```swift
// ForgeKit/AppBlockerProtocol.swift
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
        // Walk up until we find a .app directory or reach root
        while url.path != "/" {
            if url.pathExtension == "app" {
                return Bundle(url: url)?.bundleIdentifier
            }
            url = url.deletingLastPathComponent()
        }
        return nil
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/ProtectedAppsTests -only-testing:ForgeTests/BundleIDResolverTests 2>&1 | tail -20`
Expected: All 7 tests PASS

- [ ] **Step 6: Commit**

```bash
git add ForgeKit/AppBlockerProtocol.swift ForgeTests/ProtectedAppsTests.swift ForgeTests/BundleIDResolverTests.swift
git commit -m "Add ProtectedApps constants and BundleIDResolver utility"
```

---

### Task 2: Add EndpointSecurity.framework to Extension

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Read project.yml to find extension frameworks section**

Read: `project.yml` — find the `ForgeFilterExtension` target's `frameworks:` list.

- [ ] **Step 2: Add EndpointSecurity.framework**

In `project.yml`, under `ForgeFilterExtension` → `frameworks:`, add `EndpointSecurity.framework`:

```yaml
    frameworks:
      - NetworkExtension.framework
      - Network.framework
      - EndpointSecurity.framework
```

- [ ] **Step 3: Regenerate Xcode project and build**

Run: `cd /path/to/worktree && xcodegen generate && xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add project.yml
git commit -m "Add EndpointSecurity.framework to extension target"
```

---

### Task 3: EndpointSecurityBlocker

**Files:**
- Create: `ForgeFilterExtension/EndpointSecurityBlocker.swift`

- [ ] **Step 1: Implement EndpointSecurityBlocker**

```swift
// ForgeFilterExtension/EndpointSecurityBlocker.swift
import Foundation
import EndpointSecurity
import ForgeKit

final class EndpointSecurityBlocker: @unchecked Sendable {
    private var client: OpaquePointer? // es_client_t
    private let lock = NSLock()
    private var blockedBundleIDs = Set<String>()
    private var isSubscribed = false

    /// Create the ES client once. Call early in extension lifecycle.
    func createClient() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard client == nil else { return true }

        var newClient: OpaquePointer?
        let result = es_new_client(&newClient) { [weak self] _, event in
            self?.handleEvent(event)
        }

        guard result == ES_NEW_CLIENT_RESULT_SUCCESS, let newClient else {
            print("[ES] Failed to create client: \(result.rawValue)")
            return false
        }

        client = newClient
        return true
    }

    /// Activate blocking for the given bundle IDs.
    func activate(bundleIDs: Set<String>) {
        lock.lock()
        blockedBundleIDs = bundleIDs
        let currentClient = client
        let needsSubscribe = !isSubscribed
        lock.unlock()

        guard let currentClient else { return }

        // Clear mute cache so previously-muted processes are re-evaluated
        es_clear_cache(currentClient)

        if needsSubscribe {
            let events = [ES_EVENT_TYPE_AUTH_EXEC]
            let subResult = es_subscribe(currentClient, events, UInt32(events.count))
            if subResult == ES_RETURN_SUCCESS {
                lock.lock()
                isSubscribed = true
                lock.unlock()
            } else {
                print("[ES] Failed to subscribe: \(subResult.rawValue)")
            }
        }
    }

    /// Deactivate app blocking. Client stays alive.
    func deactivate() {
        lock.lock()
        blockedBundleIDs.removeAll()
        let currentClient = client
        let wasSubscribed = isSubscribed
        lock.unlock()

        guard let currentClient, wasSubscribed else { return }
        es_unsubscribe(currentClient, [ES_EVENT_TYPE_AUTH_EXEC], 1)
        es_clear_cache(currentClient)

        lock.lock()
        isSubscribed = false
        lock.unlock()
    }

    /// Destroy the ES client. Call when extension stops.
    func destroyClient() {
        lock.lock()
        defer { lock.unlock() }
        guard let currentClient = client else { return }
        es_delete_client(currentClient)
        client = nil
        isSubscribed = false
        blockedBundleIDs.removeAll()
    }

    private func handleEvent(_ event: UnsafePointer<es_message_t>) {
        guard event.pointee.event_type == ES_EVENT_TYPE_AUTH_EXEC else { return }

        let execPath = String(
            cString: event.pointee.event.exec.target.pointee.executable.pointee.path.data
        )

        let bundleID = BundleIDResolver.bundleID(forExecutableAt: execPath)

        lock.lock()
        let blocked = blockedBundleIDs
        let currentClient = client
        lock.unlock()

        // Protected apps: always allow
        if let bundleID, ProtectedApps.isProtected(bundleID) {
            es_respond_auth_result(currentClient!, event, ES_AUTH_RESULT_ALLOW, false)
            return
        }

        // Check if blocked
        if let bundleID, blocked.contains(bundleID) {
            es_respond_auth_result(currentClient!, event, ES_AUTH_RESULT_DENY, false)
            return
        }

        // Allow and mute for performance
        es_respond_auth_result(currentClient!, event, ES_AUTH_RESULT_ALLOW, false)
        if let currentClient {
            es_mute_process(currentClient, &event.pointee.process.pointee.audit_token)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ForgeFilterExtension/EndpointSecurityBlocker.swift
git commit -m "Add EndpointSecurityBlocker with AUTH_EXEC handling and process muting"
```

---

### Task 4: Wire EndpointSecurityBlocker into ExtensionXPCService

**Files:**
- Modify: `ForgeFilterExtension/ExtensionXPCService.swift`
- Modify: `ForgeFilterExtension/main.swift`

- [ ] **Step 1: Read ExtensionXPCService.swift**

Read: `ForgeFilterExtension/ExtensionXPCService.swift`

- [ ] **Step 2: Add ES blocker to ExtensionXPCService**

Add a property and wire it into `updateRuleset` and `deactivateRuleset`:

Add property after line 8 (`private weak var dnsProvider: DNSProxyProvider?`):

```swift
    private let esBlocker = EndpointSecurityBlocker()
```

In `updateRuleset`, after `dnsProvider?.applyRuleset(ruleset)` (line 39), add:

```swift
            if !ruleset.appBundleIDs.isEmpty {
                esBlocker.activate(bundleIDs: Set(ruleset.appBundleIDs))
            }
```

In `deactivateRuleset`, after `dnsProvider?.clearRuleset()` (line 50), add:

```swift
        esBlocker.deactivate()
```

- [ ] **Step 3: Read main.swift and create ES client on startup**

Read: `ForgeFilterExtension/main.swift`

After `let xpcService = ExtensionXPCService.shared` (line 4), add:

```swift
_ = xpcService.createESClient()
```

Add a public method to `ExtensionXPCService` to expose ES client creation:

```swift
    func createESClient() -> Bool {
        esBlocker.createClient()
    }
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ForgeFilterExtension/ExtensionXPCService.swift ForgeFilterExtension/main.swift
git commit -m "Wire EndpointSecurityBlocker into extension XPC service and startup"
```

---

### Task 5: WorkspaceAppBlocker

**Files:**
- Create: `Forge/Services/WorkspaceAppBlocker.swift`

- [ ] **Step 1: Implement WorkspaceAppBlocker**

```swift
// Forge/Services/WorkspaceAppBlocker.swift
import AppKit
import ForgeKit

@MainActor
final class WorkspaceAppBlocker {
    private var blockedBundleIDs = Set<String>()
    private var observer: NSObjectProtocol?

    func activate(bundleIDs: Set<String>) {
        blockedBundleIDs = bundleIDs
        guard !bundleIDs.isEmpty else { return }

        terminateRunningBlockedApps()
        startObservingLaunches()
    }

    func deactivate() {
        blockedBundleIDs.removeAll()
        stopObservingLaunches()
    }

    // MARK: - Running App Termination

    private func terminateRunningBlockedApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            guard let bundleID = app.bundleIdentifier,
                  blockedBundleIDs.contains(bundleID),
                  !ProtectedApps.isProtected(bundleID) else { continue }

            app.terminate()
            // Force terminate after 5 seconds if still running
            Task {
                try? await Task.sleep(for: .seconds(5))
                if !app.isTerminated {
                    app.forceTerminate()
                }
            }
        }
    }

    // MARK: - Launch Observation

    private func startObservingLaunches() {
        stopObservingLaunches()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }

            Task { @MainActor in
                if self.blockedBundleIDs.contains(bundleID),
                   !ProtectedApps.isProtected(bundleID) {
                    app.terminate()
                    // Force terminate after 2 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        if !app.isTerminated {
                            app.forceTerminate()
                        }
                    }
                }
            }
        }
    }

    private func stopObservingLaunches() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Forge/Services/WorkspaceAppBlocker.swift
git commit -m "Add WorkspaceAppBlocker with launch observation and running app termination"
```

---

### Task 6: Wire WorkspaceAppBlocker into BlockEngine

**Files:**
- Modify: `Forge/Services/BlockEngine.swift`

- [ ] **Step 1: Read BlockEngine.swift**

Read: `Forge/Services/BlockEngine.swift`

- [ ] **Step 2: Add WorkspaceAppBlocker property and wire into start/stop**

Add property after `private var expiryTimer: Timer?` (line 8):

```swift
    private let workspaceAppBlocker = WorkspaceAppBlocker()
```

In `startBlock`, after `writeSharedStatus(appState: appState)` (line 61), add:

```swift
        if !appBundleIDs.isEmpty {
            workspaceAppBlocker.activate(bundleIDs: Set(appBundleIDs))
        }
```

In `stopBlock`, after `appState.deactivateBlock()` (line 103), add:

```swift
        workspaceAppBlocker.deactivate()
```

In `checkExistingBlock`, after `scheduleExpiryTimer(endDate: ruleset.endDate, appState: appState)` (line 148), add:

```swift
        if !ruleset.appBundleIDs.isEmpty {
            workspaceAppBlocker.activate(bundleIDs: Set(ruleset.appBundleIDs))
        }
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Forge/Services/BlockEngine.swift
git commit -m "Wire WorkspaceAppBlocker into BlockEngine start/stop/check lifecycle"
```

---

### Task 7: Run All Tests and Final Build Verification

**Files:** None (verification only)

- [ ] **Step 1: Run all unit tests**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests PASS (including new ProtectedApps and BundleIDResolver tests)

- [ ] **Step 2: Run full build**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Verify all new files are tracked**

Run: `git status`
Expected: Clean working tree

- [ ] **Step 4: Review commit log**

Run: `git log --oneline -8`
Expected: All app blocking commits in order
