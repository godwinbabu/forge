# Phase 7: Onboarding, Recovery, and Polish

**Date:** 2026-03-29
**Status:** Approved
**Scope:** Onboarding flow, commitment enforcement, recovery CLI, browser cache clearing, settings view

---

## 7.1: Onboarding Flow

4-step progressive onboarding on first launch:

1. **Welcome:** App purpose, commitment model explanation, "Get Started" button
2. **Extension Approval:** Guide user to approve the system extension in System Settings, detect approval via `FilterManagerService.isEnabled`, advance automatically
3. **First Profile:** Pick from preset categories (Social Media, News, Gaming) or skip. Creates profile from preset.
4. **First Block:** "Try a 15-minute block" with the selected profile, or "Skip" to go to dashboard

Track completion in `UserDefaults` key `forge.onboarding.completed`. Show onboarding on first launch only.

**Files:** `Forge/Views/Onboarding/OnboardingView.swift` (all 4 steps in one file with step state)

## 7.2: Commitment Enforcement

During active block:
- ⌘Q intercepted via `NSApplication.shared.delegate` implementing `applicationShouldTerminate` → return `.terminateCancel` when block is active
- Menu bar "Quit" already disabled (implemented in MenuBarView)
- Window close button hidden during block (`.windowResizability` or override)

**Files:** Modify `Forge/App/ForgeApp.swift` to set up an `NSApplicationDelegate` that prevents termination.

## 7.3: Recovery CLI

Simplified recovery (no PF rules in the simplified architecture):
- Read block status from App Group UserDefaults
- Clear the shared status keys
- Print instructions to disable the extension in System Settings
- `forge recover --force` skips confirmation prompt

**Files:** Modify `forge-cli/RecoverCommand.swift`

## 7.4: Browser Cache Clearing

When `profile.clearBrowserCaches` is true, on block start:
- Delete Chrome cache: `~/Library/Caches/Google/Chrome/`
- Delete Safari cache: `~/Library/Caches/com.apple.Safari/`
- Delete Firefox cache: `~/Library/Caches/Firefox/`
- Flush DNS: run `dscacheutil -flushcache`

**Files:** Create `Forge/Services/BrowserCacheClearer.swift`, call from `BlockEngine.startBlock`

## 7.5: Settings View

Replace the stub with:
- **General section:** Launch at login toggle (via `SMAppService`), notification preferences
- **Blocking section:** Default block duration slider
- **Recovery section:** "Emergency Recovery" button that runs the recovery steps
- **About section:** Version, build number

**Files:** Rewrite `Forge/Views/Settings/SettingsView.swift`

---

## Files

### Create
| File | Purpose |
|------|---------|
| `Forge/Views/Onboarding/OnboardingView.swift` | 4-step onboarding flow |
| `Forge/Services/BrowserCacheClearer.swift` | Delete browser caches and flush DNS |
| `Forge/Services/AppDelegate.swift` | NSApplicationDelegate for ⌘Q prevention |

### Modify
| File | Change |
|------|--------|
| `Forge/App/ForgeApp.swift` | Wire AppDelegate, show onboarding on first launch |
| `Forge/Services/BlockEngine.swift` | Call BrowserCacheClearer on block start |
| `Forge/Views/Settings/SettingsView.swift` | Replace stub with real settings |
| `forge-cli/RecoverCommand.swift` | Implement recovery steps |
