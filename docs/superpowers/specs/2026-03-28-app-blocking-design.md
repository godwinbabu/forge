# Phase 4: App Blocking Engine

**Date:** 2026-03-28
**Status:** Approved
**Based on:** `docs/design-spec.md` Section 6 (App Blocking Engine)
**Scope:** Engine + integration only. App picker UI deferred to Phase 5.

---

## Goal

Prevent blocked apps from launching during an active block. Primary mechanism uses EndpointSecurity (`AUTH_EXEC` denial). Fallback uses `NSWorkspace` observation + process termination when the ES entitlement is unavailable.

---

## Architecture

```
ForgeKit/
  AppBlockerProtocol.swift          Protocol shared between primary and fallback

ForgeFilterExtension/
  EndpointSecurityBlocker.swift     ES client: AUTH_EXEC subscription, bundle ID check, muting

Forge/
  Services/WorkspaceAppBlocker.swift  Fallback: NSWorkspace observe + terminate
```

### EndpointSecurityBlocker (Primary)

Runs in the system extension (root process). On block start:

1. Creates an `es_client_t` via `es_new_client`
2. Subscribes to `ES_EVENT_TYPE_AUTH_EXEC`
3. For each exec event: extracts executable path → resolves bundle ID via `Bundle(url:)`
4. Checks bundle ID against `blockedBundleIDs: Set<String>`
5. Returns `ES_AUTH_RESULT_DENY` for blocked apps, `ES_AUTH_RESULT_ALLOW` otherwise

On block end: calls `es_delete_client` to stop all monitoring.

**Performance:**
- Cache allow decisions: mute non-blocked executables via `es_mute_process`
- Mute system processes aggressively (compilers, shells, daemons)
- Decision is a `Set.contains` check — O(1), <1ms
- Protected apps list checked first (always allow)

**Protected apps (never blocked):**
- `com.apple.finder`
- `com.apple.systempreferences` / `com.apple.SystemSettings`
- `com.apple.loginwindow`
- `com.apple.SecurityAgent`
- `com.apple.Terminal`
- `app.forge.Forge` (self)

### WorkspaceAppBlocker (Fallback)

Runs in the main app. When ES entitlement is unavailable:

1. Observes `NSWorkspace.didLaunchApplicationNotification`
2. On launch notification: checks `bundleIdentifier` against blocked set
3. If blocked: calls `terminate()`, then `forceTerminate()` after 2 seconds
4. On block start: also enumerates `NSWorkspace.shared.runningApplications` and terminates any currently-running blocked apps

### Already-Running App Handling

On block start (both implementations):

1. Enumerate running apps
2. For each app with a blocked bundle ID (excluding protected apps):
   - Send `SIGTERM` (graceful quit)
   - After 5 seconds, send `SIGKILL` if still running

For EndpointSecurityBlocker, this runs in the extension. For WorkspaceAppBlocker, this runs in the main app.

### Shared Protocol

```swift
public protocol AppBlocker: Sendable {
    func activate(bundleIDs: Set<String>) async
    func deactivate() async
}
```

Both implementations conform to this protocol. `ExtensionXPCService` calls the ES blocker. `BlockEngine` uses the workspace blocker as fallback.

---

## Integration

### Extension Side

`ExtensionXPCService.updateRuleset()` already receives `BlockRuleset` which contains `appBundleIDs: [String]`. After applying network rules, it also activates the `EndpointSecurityBlocker` with the app bundle IDs.

`ExtensionXPCService.deactivateRuleset()` deactivates both network filtering and app blocking.

### App Side (Fallback)

`BlockEngine.startBlock()` checks if the extension is handling app blocking (it can query via XPC). If not, it activates the `WorkspaceAppBlocker` locally.

The fallback is a best-effort mechanism — the extension-based blocker is authoritative.

### XPC Protocol Extension

Add a method to `ForgeExtensionProtocol` to query whether ES is available:

```swift
func getCapabilities(reply: @escaping (Data?) -> Void)
```

Returns a `Capabilities` struct indicating whether ES app blocking is active.

---

## Files

### Create

| File | Target | Purpose |
|------|--------|---------|
| `ForgeKit/AppBlockerProtocol.swift` | ForgeKit | `AppBlocker` protocol + `ProtectedApps` constants |
| `ForgeFilterExtension/EndpointSecurityBlocker.swift` | Extension | ES client lifecycle + AUTH_EXEC handling |
| `Forge/Services/WorkspaceAppBlocker.swift` | App | NSWorkspace fallback blocker |
| `ForgeTests/ProtectedAppsTests.swift` | Tests | Protected apps list tests |
| `ForgeTests/WorkspaceAppBlockerTests.swift` | Tests | Fallback blocker logic tests |

### Modify

| File | Change |
|------|--------|
| `ForgeFilterExtension/ExtensionXPCService.swift` | Activate/deactivate ES blocker alongside NE |
| `Forge/Services/BlockEngine.swift` | Fallback app blocking when ES unavailable |
| `ForgeKit/XPCProtocol.swift` | Add `getCapabilities` method |
| `project.yml` | Add `EndpointSecurity.framework` to extension |

---

## Testing

**Unit tests (ForgeKit scheme):**
- Protected apps list: verify all expected bundle IDs present
- Protected apps check: verify a protected bundle ID is recognized

**Build verification:**
- Extension builds with EndpointSecurity.framework linked
- App builds with WorkspaceAppBlocker
- Full project compiles

**Integration tests (manual):**
- Start block with app in blocklist → launch app → denied (ES) or terminated (fallback)
- Start block with blocked app already running → app terminated
- Protected app (Finder) never blocked
- Block end → all apps launchable again

---

## Risks

| Risk | Mitigation |
|------|-----------|
| Apple denies ES entitlement | WorkspaceAppBlocker fallback (reactive but functional) |
| ES client creation fails at runtime | Graceful degradation — log error, continue without app blocking |
| Performance impact from AUTH_EXEC | Aggressive muting of non-blocked processes |
| App briefly visible before kill (fallback) | Acceptable UX — competitor apps (Freedom, Focus) work this way |
