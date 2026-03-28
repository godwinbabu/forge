# Phase 4: App Blocking Engine

**Date:** 2026-03-28
**Status:** Approved
**Based on:** `docs/design-spec.md` Section 6 (App Blocking Engine)
**Scope:** Engine + integration only. App picker UI deferred to Phase 5.

---

## Goal

Prevent blocked apps from launching during an active block. Primary mechanism uses EndpointSecurity (`AUTH_EXEC` denial) in the system extension. Fallback uses `NSWorkspace` observation + process termination in the main app. Both can run simultaneously as belt-and-suspenders.

---

## Architecture

```
ForgeKit/
  AppBlockerProtocol.swift          Protocol + ProtectedApps constants + BundleIDResolver utility

ForgeFilterExtension/
  EndpointSecurityBlocker.swift     ES client: AUTH_EXEC subscription, bundle ID check, muting

Forge/
  Services/WorkspaceAppBlocker.swift  Fallback: NSWorkspace observe + terminate + running app cleanup
```

### EndpointSecurityBlocker (Primary — Extension)

Runs in the system extension (root process). Blocks new app launches only — does not handle already-running apps.

**Lifecycle:**
- ES client created once during extension startup (not per-block)
- `activate(bundleIDs:)` updates the blocked set and subscribes to `ES_EVENT_TYPE_AUTH_EXEC`
- `deactivate()` unsubscribes from events and clears the blocked set (client stays alive)
- Client destroyed only when extension stops

**AUTH_EXEC handler:**
1. Extract executable path from `es_event_exec_t`
2. Resolve to bundle ID: walk up from executable to find `.app` bundle, read `CFBundleIdentifier` from its `Info.plist`
3. If bundle ID is in protected set → `ES_AUTH_RESULT_ALLOW`
4. If bundle ID is in blocked set → `ES_AUTH_RESULT_DENY`
5. Otherwise → `ES_AUTH_RESULT_ALLOW` + `es_mute_process` (cache the allow)

**Performance:**
- Mute non-blocked executables via `es_mute_process` — they never trigger callbacks again
- When blocked set changes (new block or extend), call `es_clear_cache` to re-evaluate muted processes
- Decision is `Set.contains` — O(1), sub-millisecond
- Protected apps checked first (fast path)

**Protected apps (never blocked):**
- `com.apple.finder`
- `com.apple.systempreferences`
- `com.apple.SystemSettings`
- `com.apple.loginwindow`
- `com.apple.SecurityAgent`
- `com.apple.Terminal`
- `app.forge.Forge`
- `app.forge.Forge.ForgeFilterExtension`

### WorkspaceAppBlocker (Fallback + Running App Handler — App)

Runs in the main app. Handles two responsibilities:

**1. Already-running app termination (always active):**
On block start, enumerates `NSWorkspace.shared.runningApplications`. For each app with a blocked bundle ID (excluding protected apps):
- Call `terminate()` (graceful quit via Apple Events)
- After 5 seconds, call `forceTerminate()` if still running

**2. Launch observation (fallback when ES unavailable, also belt-and-suspenders):**
- Observes `NSWorkspace.didLaunchApplicationNotification`
- On launch: checks `bundleIdentifier` against blocked set
- If blocked: calls `terminate()`, then `forceTerminate()` after 2 seconds

The workspace blocker always runs during active blocks. If ES is also active, it provides a second layer — ES blocks the launch at kernel level, workspace catches anything that slips through.

### Bundle ID Resolution

Utility in ForgeKit for resolving executable paths to bundle IDs:

```swift
public enum BundleIDResolver {
    /// Walk up from executable path to find .app bundle, read CFBundleIdentifier
    public static func bundleID(forExecutableAt path: String) -> String?
}
```

Algorithm: Starting from the executable path, walk up parent directories until finding a `.app` directory. Create `Bundle(path:)` from it and return `bundleIdentifier`.

---

## Integration

### Extension Side

`ExtensionXPCService.updateRuleset()` already receives `BlockRuleset` with `appBundleIDs: [String]`. After applying network rules, it activates `EndpointSecurityBlocker` with those bundle IDs.

`ExtensionXPCService.deactivateRuleset()` deactivates both network filtering and app blocking.

If ES client creation fails (entitlement not granted, or runtime error), log the error and continue — network blocking still works, and the app-side workspace blocker provides app blocking.

### App Side

`BlockEngine.startBlock()` activates `WorkspaceAppBlocker` with the profile's `appBundleIDs`. This handles:
1. Terminating already-running blocked apps
2. Observing for new launches (belt-and-suspenders with ES, or sole mechanism if ES unavailable)

`BlockEngine.stopBlock()` deactivates the `WorkspaceAppBlocker`.

No new XPC methods needed — the app always runs the workspace blocker regardless of ES availability.

---

## Files

### Create

| File | Target | Purpose |
|------|--------|---------|
| `ForgeKit/AppBlockerProtocol.swift` | ForgeKit | `AppBlocker` protocol, `ProtectedApps` set, `BundleIDResolver` |
| `ForgeFilterExtension/EndpointSecurityBlocker.swift` | Extension | ES client lifecycle + AUTH_EXEC handling |
| `Forge/Services/WorkspaceAppBlocker.swift` | App | NSWorkspace fallback + running app termination |
| `ForgeTests/BundleIDResolverTests.swift` | Tests | Bundle ID resolution from executable paths |
| `ForgeTests/ProtectedAppsTests.swift` | Tests | Protected apps list completeness |

### Modify

| File | Change |
|------|--------|
| `ForgeFilterExtension/ExtensionXPCService.swift` | Activate/deactivate ES blocker alongside NE providers |
| `Forge/Services/BlockEngine.swift` | Activate/deactivate WorkspaceAppBlocker on block start/stop |
| `project.yml` | Add `EndpointSecurity.framework` to extension target |

---

## Testing

**Unit tests (ForgeKit scheme):**
- `BundleIDResolver`: resolves `/Applications/Safari.app/Contents/MacOS/Safari` → `com.apple.Safari`
- `BundleIDResolver`: returns nil for non-app executables (e.g., `/usr/bin/ls`)
- `ProtectedApps`: verify all expected bundle IDs present
- `ProtectedApps.isProtected()`: correctly identifies protected and non-protected apps

**Build verification:**
- Extension builds with EndpointSecurity.framework linked
- Full project compiles

**Manual integration tests:**
- Start block with app in blocklist → launch app → denied (ES) or terminated (fallback)
- Start block with blocked app already running → app terminated
- Protected app (Finder, Terminal) never blocked
- Block end → all apps launchable again

---

## Risks

| Risk | Mitigation |
|------|-----------|
| Apple denies ES entitlement | WorkspaceAppBlocker always runs as fallback |
| ES client creation fails at runtime | Log error, continue — workspace blocker handles it |
| Performance impact from AUTH_EXEC | Aggressive muting of non-blocked processes via `es_mute_process` |
| App briefly visible before kill (fallback) | Acceptable — competitors (Freedom, Focus) work the same way |
| Blocked set changes mid-block | `es_clear_cache` re-evaluates muted processes against new set |
