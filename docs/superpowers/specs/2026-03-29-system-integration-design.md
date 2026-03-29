# Phase 6: System Integration

**Date:** 2026-03-29
**Status:** Approved
**Scope:** Notifications, keyboard shortcuts, command palette, App Intents, desktop widgets, iCloud sync, Focus mode integration

---

## Sub-features

### 6a: Notifications

Request notification permission on first block end. Send notifications for:
- Block started via schedule: "{Profile} activated — Ends at {time}"
- Block ending soon (5 min): "Focus session ends in 5 minutes"
- Block ended: "Your block has ended. You blocked {N} distractions!"

Implementation: `NotificationService` in `Forge/Services/`. Uses `UNUserNotificationCenter`. Schedule the "ending soon" notification when a block starts. Send "block ended" from `BlockEngine.stopBlock`. Send "schedule started" from `ScheduleEvaluator`.

### 6b: Keyboard Shortcuts

Register in `ForgeApp.swift` via `.keyboardShortcut` on `Commands`:
- ⌘1-9: quick-start pinned profiles 1-9
- ⌘N: new profile (navigate to profiles, open editor)
- ⌘,: settings
- ⌘K: command palette (toggle)

Implementation: Add a `Commands` group to the `WindowGroup` scene. Profile quick-start uses SwiftData query.

### 6c: Command Palette (⌘K)

Overlay view with:
- Search field (auto-focused)
- Results list with fuzzy matching
- Keyboard navigation (up/down, Enter to execute, Escape to close)
- Actions: start profiles, navigate to sections, add domain to profile

Implementation: `CommandPaletteView` as overlay in `ContentView`. `CommandAction` struct with title, icon, and closure. `FuzzyMatcher` in ForgeKit for testable search logic.

### 6d: App Intents + Shortcuts

App Intents for Shortcuts.app and widgets:
- `StartBlockIntent`: pick profile + duration → start block
- `GetBlockStatusIntent`: returns remaining time or "no active block"
- `ExtendBlockIntent`: extend by N minutes

No `StopBlockIntent` — blocks can't be stopped early (commitment mechanism).

Implementation: `Forge/Intents/` directory. Intents use `AppEntity` for profiles and `AppShortcutsProvider` for discoverability.

### 6e: Desktop Widgets

Update existing widget infrastructure:
- Small: countdown timer + profile name (or "Ready to focus")
- Medium: timer + blocked attempts + profile name

`TimelineProvider` reads from App Group UserDefaults (already written by `BlockEngine.writeSharedStatus`). Interactive buttons deferred (require App Intent integration which is complex for widgets).

### 6f: iCloud Sync

`NSUbiquitousKeyValueStore` for profiles and schedules:
- Encode each profile/schedule as JSON under its UUID key
- Listen for `didChangeExternallyNotification` → merge into local SwiftData
- Conflict resolution: last-writer-wins via `updatedAt`
- Sync on profile/schedule save, and on app launch

Implementation: Replace `ICloudSyncService` stub. Add iCloud KVS entitlement.

### 6g: Focus Mode Integration

Deferred to Phase 7 — requires `INFocusStatusCenter` which has limited macOS support and adds complexity without high value for v1.

---

## Files

### Create

| File | Purpose |
|------|---------|
| `Forge/Services/NotificationService.swift` | UNUserNotificationCenter wrapper |
| `Forge/Views/Shared/CommandPaletteView.swift` | ⌘K overlay with fuzzy search |
| `ForgeKit/FuzzyMatcher.swift` | Fuzzy string matching for command palette |
| `Forge/Intents/StartBlockIntent.swift` | App Intent to start a block |
| `Forge/Intents/GetBlockStatusIntent.swift` | App Intent to query block status |
| `Forge/Intents/ExtendBlockIntent.swift` | App Intent to extend a block |
| `Forge/Intents/ProfileEntity.swift` | AppEntity for profile selection in intents |
| `Forge/Intents/ForgeShortcuts.swift` | AppShortcutsProvider for Shortcuts.app |
| `ForgeTests/FuzzyMatcherTests.swift` | Fuzzy matching tests |
| `ForgeTests/NotificationServiceTests.swift` | Notification scheduling tests |

### Modify

| File | Change |
|------|--------|
| `Forge/App/ForgeApp.swift` | Add Commands for keyboard shortcuts |
| `Forge/App/ContentView.swift` | Add command palette overlay, ⌘K toggle |
| `Forge/App/AppState.swift` | Add `showingCommandPalette` property |
| `Forge/Services/BlockEngine.swift` | Send notifications on block start/stop |
| `Forge/Services/ScheduleEvaluator.swift` | Send notification on scheduled block start |
| `Forge/Services/iCloudSyncService.swift` | Replace stub with NSUbiquitousKeyValueStore impl |
| `ForgeWidget/ForgeWidget.swift` | Update widget views |
| `ForgeWidget/TimelineProvider.swift` | Read from App Group UserDefaults |
| `Forge.entitlements` | Add iCloud KVS entitlement |
