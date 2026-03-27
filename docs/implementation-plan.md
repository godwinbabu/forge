# Forge — Implementation Plan

**Date:** 2026-03-27
**Based on:** [Design Specification](design-spec.md)
**Approach:** Phased delivery — each phase produces a working, testable artifact

---

## Principles

1. **Each phase is independently shippable** — no phase depends on a later phase to be useful
2. **Blocking engine first, UI second** — the core promise (unbypassable blocks) must work before we polish the interface
3. **Test as you go** — each phase includes its own tests; no "add tests later" phase
4. **Entitlement risk upfront** — apply for Apple entitlements in Phase 0 so we're not blocked later
5. **Incremental complexity** — start with single-profile blocking, add profiles/schedules/sync in later phases

---

## Phase 0: Project Scaffolding & Entitlement Applications

**Goal:** Xcode project compiles, CI runs, Apple entitlement requests submitted.

### Tasks

- [ ] **0.1** Create Xcode project with all targets:
  - `Forge` (macOS app, SwiftUI lifecycle)
  - `ForgeFilterExtension` (System Extension — Network Extension + EndpointSecurity)
  - `ForgeHelper` (privileged helper tool for SMJobBless)
  - `forge-cli` (command-line tool, Swift ArgumentParser)
  - `ForgeWidget` (WidgetKit extension)
  - `ForgeTests` (unit test target)
  - `ForgeIntegrationTests` (integration test target)
  - `ForgeUITests` (UI test target)
- [ ] **0.2** Configure build settings:
  - Deployment target: macOS 15.0
  - Swift 6 language mode
  - Strict concurrency checking enabled
  - App Group identifier configured (`group.app.forge`)
  - Code signing with Developer ID
- [ ] **0.3** Configure entitlements files:
  - App: `com.apple.developer.networking.networkextension`, `com.apple.security.application-groups`
  - Extension: `com.apple.developer.networking.networkextension`, `com.apple.developer.endpoint-security.client`, `com.apple.security.app-sandbox`, `com.apple.security.application-groups`
  - Helper: no entitlements (SMJobBless, unsandboxed)
- [ ] **0.4** Submit Apple entitlement requests:
  - Network Extension (content-filter-provider, dns-proxy) — development profile
  - EndpointSecurity — development profile
  - Document: request justification referencing SelfControl's 15+ year history as a legitimate content filter
- [ ] **0.5** Set up GitHub Actions CI:
  - Build all targets on `macos-15` runner
  - Run SwiftLint
  - Run unit tests
  - Trigger on PR and push to `main`
- [ ] **0.6** Add SwiftLint configuration (`.swiftlint.yml`)
- [ ] **0.7** Add `.gitignore`, `CLAUDE.md` for the new project
- [ ] **0.8** Create Sparkle 2 integration (add SPM dependency, configure EdDSA key pair)

### Exit Criteria
- `xcodebuild -scheme Forge build` succeeds for all targets
- CI pipeline runs green on GitHub
- Apple entitlement requests submitted (not necessarily approved yet)

### Estimated complexity: Medium
### Dependencies: None

---

## Phase 1: Privileged Helper + PF Enforcement

**Goal:** The enforcement backbone works — PF rules can be installed, verified, and cleanly removed. This is the foundation everything else builds on.

### Tasks

- [ ] **1.1** Implement `ForgeHelper` XPC service:
  - `ForgeHelperProtocol` with `startEnforcement`, `extendBlock`, `removeEnforcement`, `getStatus`, `getVersion`
  - XPC listener setup with Mach service name
  - Client code signing validation (SecCode + auditToken)
  - Authorization via `AuthorizationRef` (Touch ID / admin password)
  - Rate limiting (3 failures in 60s → 5-minute lockout)
- [ ] **1.2** Implement `PFManager`:
  - Write PF anchor rules to `/etc/pf.anchors/app.forge.block`
  - Append anchor reference to `/etc/pf.conf` (identifiable by anchor name)
  - Atomic writes: write temp → chown root:wheel → chmod 644 → rename
  - Reload via `pfctl -E -f /etc/pf.conf`
  - Remove: strip anchor lines from pf.conf, flush anchor, delete anchor file
  - Verify: `pfctl -a app.forge.block -sr` to confirm rules loaded
- [ ] **1.3** Implement `ManifestManager`:
  - `SystemStateManifest` Codable struct (blockID, dates, PF state, cleanup state, block params)
  - Atomic write to `/Library/Application Support/Forge/manifest.json`
  - Read/delete operations
  - World-readable permissions (0644, root:wheel)
- [ ] **1.4** Implement `CleanupInstaller`:
  - Install LaunchDaemon plist at `/Library/LaunchDaemons/app.forge.cleanup.plist`
  - `StartInterval: 30` (polls every 30 seconds)
  - Bundle `cleanup.sh` script to `/Library/Application Support/Forge/cleanup.sh`
  - Cleanup script: check manifest expiry → strip pf.conf → flush anchor → self-remove
  - Cleanup script: if block active and anchor missing → re-add (OS update resilience)
- [ ] **1.5** Implement SMJobBless integration:
  - Helper binary in app bundle
  - Info.plist with `SMPrivilegedExecutables` / `SMAuthorizedClients`
  - Install/upgrade helper on app launch
- [ ] **1.6** Implement `XPCClient` (app-side):
  - Connect to helper via Mach service
  - Authorization setup (create AuthorizationRef, convert to external form)
  - Methods: `startEnforcement`, `extendBlock`, `removeEnforcement`, `getStatus`
  - Connection recovery on helper crash
- [ ] **1.7** Write unit tests:
  - PF rule generation (anchor file content for blocklist/allowlist modes)
  - Manifest encoding/decoding, version handling
  - Cleanup script logic (mock filesystem)
- [ ] **1.8** Write integration tests:
  - Full cycle: install rules → verify active → remove → verify clean
  - Extend block → verify new end date in manifest
  - Cleanup timer: install → simulate expiry → verify removal

### Exit Criteria
- Helper installs via SMJobBless, accepts XPC connections
- PF rules block traffic to specified IPs/domains
- Cleanup timer fires and removes all state on expiry
- System returns to pristine state after block removal
- All tests pass

### Estimated complexity: High
### Dependencies: Phase 0

---

## Phase 2: Network Extension — DNS Proxy + Content Filter

**Goal:** Website blocking via Network Extension. Blocks DNS queries and network flows, including DoH bypass protection.

### Tasks

- [ ] **2.1** Implement `NEDNSProxyProvider`:
  - `startProxy(options:completionHandler:)` lifecycle
  - Intercept DNS queries via `handleNewFlow`
  - Check domain against active ruleset → return NXDOMAIN (`0.0.0.0`/`::`) or forward
  - Build IP→hostname mapping table (shared with content filter)
  - Wildcard domain matching (`*.reddit.com`)
  - Common subdomain expansion (`www.*`, `m.*`)
- [ ] **2.2** Implement `NEFilterDataProvider`:
  - `startFilter(completionHandler:)` lifecycle
  - `handleNewFlow` — check `remoteHostname` against ruleset
  - When `remoteHostname` is nil: look up IP in DNS proxy's IP→hostname map
  - SNI inspection fallback: extract hostname from TLS ClientHello in `handleOutboundData`
  - DoH server blocking: block connections to known DoH resolver IPs (configurable list)
  - Allowlist mode: drop all except matched + essential services (DNS 53, NTP 123, DHCP 67-68, mDNS 5353)
  - Blocklist mode: drop matched, allow all else
- [ ] **2.3** Implement `RulesetStore`:
  - Persist active `BlockRuleset` to extension's own container (JSON file)
  - Load on `startFilter()` / `startProxy()` for reboot survival
  - Delete on block expiry
  - Check `endDate` on load — if expired, clean up and start with no rules
- [ ] **2.4** Implement `BlockRuleset` model:
  - `DomainRule` enum: `.exact`, `.wildcard`, `.cidr`, `.portSpecific`
  - Matching logic with unit tests
  - DoH server IP list (configurable, loaded from bundled JSON)
- [ ] **2.5** Implement XPC communication (app → extension):
  - Extension declares Mach service in Info.plist
  - Extension creates `NSXPCListener` on startup
  - App connects via `NSXPCConnection(machServiceName:options:.privileged)`
  - Protocol: `updateRuleset(_ :)`, `deactivateRuleset()`, `getStatus(reply:)`
  - Bidirectional: extension pushes blocked flow events back to app via exported interface
  - Buffer events if app not connected
- [ ] **2.6** Implement `NEFilterManager` configuration:
  - App calls `NEFilterManager.shared().loadFromPreferences()`
  - Sets `isEnabled = true`, configures provider
  - `saveToPreferences()` — persists across reboots
  - Extension auto-starts on boot without app
- [ ] **2.7** Implement DoH server IP list:
  - Bundled `doh-servers.json` with Google, Cloudflare, Quad9, OpenDNS, NextDNS, AdGuard IPs
  - Updatable without app release (UserDefaults override or remote config)
- [ ] **2.8** Write unit tests:
  - `BlockRuleset` matching: exact, wildcard, CIDR, port-specific
  - DoH server list loading and matching
  - Ruleset encoding/decoding
  - SNI extraction from TLS ClientHello bytes
- [ ] **2.9** Write integration tests:
  - App → extension XPC: send ruleset, verify applied
  - DNS proxy blocks domain, returns NXDOMAIN
  - Content filter blocks flow by IP when hostname unavailable
  - Reboot simulation: persist ruleset, restart extension, verify rules reload
  - Block expiry: extension detects expired ruleset, clears rules

### Exit Criteria
- Websites blocked at DNS level (system DNS queries intercepted)
- DoH bypass prevented (DoH server IPs blocked, browsers fall back to system DNS)
- Chromium-based browsers blocked despite nil `remoteHostname` (IP→hostname map works)
- Extension persists rules across reboot
- Extension auto-cleans expired rules
- All tests pass

### Estimated complexity: Very High
### Dependencies: Phase 0 (entitlements must be approved)

---

## Phase 3: Block Engine Orchestration + Basic UI

**Goal:** A user can start, extend, and stop a block through a minimal but functional SwiftUI interface. All three enforcement layers work together.

### Tasks

- [ ] **3.1** Implement `BlockEngine` service:
  - Orchestrates the three-layer block start sequence:
    1. Authenticate (Touch ID / admin)
    2. Build `BlockRuleset` from domain/app list
    3. Send ruleset to extension via XPC
    4. Send manifest to helper via XPC
    5. Record `BlockSession` in SwiftData
  - Extend block (update end date across all layers)
  - Stop block on expiry (deactivate extension, remove enforcement via helper)
  - Query block status from manifest + extension
- [ ] **3.2** Implement SwiftData models:
  - `BlockProfile` (name, icon, color, mode, domains, appBundleIDs, settings)
  - `BlockSchedule` (profile, weekdays, start/end time, enabled)
  - `BlockSession` (dates, domains snapshot, mode, blocked attempts, trigger)
  - Configure `ModelContainer` with App Group container
  - Seed with built-in preset profiles (Social Media, News, Gaming)
- [ ] **3.3** Implement minimal main window (SwiftUI):
  - `NavigationSplitView` with sidebar (Dashboard, Profiles, Settings)
  - Dashboard: show "no active block" with a profile card and duration slider, or active block countdown
  - Profile list view (read-only for now, uses preset profiles)
  - Settings view (placeholder)
- [ ] **3.4** Implement menu bar interface:
  - `NSStatusItem` with SF Symbol icon
  - Popover with: block status, quick-start for first profile, "Open Forge..." link
  - Suppress Dock icon (`LSUIElement` in Info.plist), show only menu bar
  - Optional Dock icon mode via settings
- [ ] **3.5** Implement countdown timer:
  - `CountdownTimerView` (shared between dashboard, menu bar, widget)
  - Updates every second
  - Shows "Finishing..." state during cleanup
- [ ] **3.6** Implement block start flow:
  - User picks profile → taps Start → duration slider → Touch ID → block active
  - UI transitions to active block state (countdown, progress bar)
  - "Add Site" and "Extend" buttons in active state
- [ ] **3.7** Implement block expiry flow:
  - Timer reaches zero → `BlockEngine` deactivates all layers
  - UI transitions back to "ready" state
  - `UserNotification` sent: "Your block has ended!"
- [ ] **3.8** Write unit tests:
  - `BlockEngine` orchestration (mock XPC clients)
  - SwiftData model validation
  - Preset profile loading
- [ ] **3.9** Write UI tests:
  - Start a block via dashboard → verify timer appears
  - Extend a block → verify new time
  - Block expires → verify UI returns to ready state

### Exit Criteria
- User can start a block from the UI using a preset profile
- All three enforcement layers activate (NE + PF + cleanup timer)
- Countdown timer updates in real-time
- Block expires cleanly, all layers deactivate
- System notification on block end
- Menu bar shows block status

### Estimated complexity: High
### Dependencies: Phase 1, Phase 2

---

## Phase 4: App Blocking (EndpointSecurity)

**Goal:** Blocked apps cannot launch during an active block.

### Tasks

- [ ] **4.1** Implement `EndpointSecurityAppBlocker`:
  - Create ES client in the system extension
  - Subscribe to `ES_EVENT_TYPE_AUTH_EXEC`
  - Extract executable path → resolve to bundle ID
  - Check against `activeRuleset.appBundleIDs` → deny or allow
  - Cache allow results for non-blocked executables
  - Mute trusted processes (`es_mute_process`) for performance
  - Respond in <1ms (set membership check only)
- [ ] **4.2** Implement `WorkspaceAppBlocker` (fallback):
  - Observe `NSWorkspace.didLaunchApplicationNotification`
  - Kill matching apps via `NSRunningApplication.terminate()` then `forceTerminate()`
  - Conforms to same `AppBlocker` protocol
- [ ] **4.3** Implement already-running app handling:
  - On block start: enumerate running apps via `NSWorkspace.runningApplications`
  - Send `SIGTERM` to blocked apps
  - After 5 seconds, `SIGKILL` if still running
  - Protected apps list (Finder, System Settings, loginwindow, Terminal, Forge itself)
- [ ] **4.4** Implement app picker UI:
  - Profile editor: "Apps" section with "Add App" button
  - List installed apps via `LSApplicationRecord` (or `NSWorkspace`)
  - Show app icon + name, selectable
  - Store selected bundle IDs in profile
- [ ] **4.5** Integrate app blocking into `BlockEngine`:
  - Include `appBundleIDs` in `BlockRuleset` sent to extension
  - Extension activates ES blocking alongside NE filtering
  - On block end: extension deactivates ES blocking
- [ ] **4.6** Write unit tests:
  - Bundle ID resolution from executable path
  - Protected apps list enforcement
  - Fallback protocol conformance
- [ ] **4.7** Write integration tests:
  - Start block with app in blocklist → attempt to launch → denied
  - Start block with app already running → app terminated
  - Protected app not terminated

### Exit Criteria
- Blocked apps cannot launch (ES `AUTH_DENY` or workspace kill)
- Already-running blocked apps are terminated on block start
- System apps are never blocked
- App picker UI works in profile editor
- Fallback to workspace approach if ES entitlement unavailable

### Estimated complexity: High
### Dependencies: Phase 2 (extension infrastructure), Phase 3 (UI)

---

## Phase 5: Profiles, Scheduling, and Insights

**Goal:** Multiple profiles, recurring schedules, and usage analytics.

### Tasks

- [ ] **5.1** Implement Profile Editor UI:
  - Name, SF Symbol icon picker, color picker
  - Mode toggle (blocklist/allowlist)
  - Domain list: add/remove/edit, paste multiple, validation
  - App list: picker from installed apps (from Phase 4)
  - Per-profile options: subdomain expansion, local network, cache clearing
  - Import preset: dropdown with built-in lists
  - Import/export profile as JSON
- [ ] **5.2** Implement Schedule Editor UI:
  - Weekday selector (multi-select chips)
  - Start time / end time pickers
  - Profile assignment dropdown
  - Enabled/disabled toggle
  - List view showing all schedules as cards
- [ ] **5.3** Implement `ScheduleEvaluator`:
  - Runs every 30 seconds (app or menu bar agent)
  - Evaluates all enabled schedules against current time/weekday
  - Handles overnight spans (10 PM → 6 AM)
  - Handles wake-from-sleep (start block for remaining window)
  - Avoids duplicate blocks (check if profile already active)
  - Integrates with `BlockEngine` to start scheduled blocks
- [ ] **5.4** Implement Insights view:
  - Swift Charts: focus time area chart (week/month toggle)
  - Swift Charts: most-blocked sites horizontal bar chart
  - Streak counter (consecutive days with at least one block session)
  - Streak calendar (GitHub contribution-graph style)
  - Total stats: focus time, sessions, blocked attempts
  - Aggregated from `BlockSession` records in SwiftData
- [ ] **5.5** Implement `AnalyticsService`:
  - Aggregate `BlockSession` data by day/week/month
  - Calculate streaks
  - Track blocked attempt counts (receive from extension via XPC)
  - Increment `blockedAttemptCount` on `BlockSession` during active block
- [ ] **5.6** Implement blocked attempt tracking:
  - Extension sends blocked flow events to app via XPC callback
  - App buffers and counts per-domain
  - Display in active block view ("reddit.com — 14 attempts")
  - Store aggregate in `BlockSession` for insights
- [ ] **5.7** Write unit tests:
  - Schedule evaluator: same-day, overnight, wake-from-sleep, duplicate prevention
  - Analytics aggregation: daily/weekly/monthly rollups, streak calculation
  - Profile validation: required fields, domain format
- [ ] **5.8** Write UI tests:
  - Create profile → add domains → save → verify in list
  - Create schedule → assign profile → enable → verify
  - View insights → verify charts render with data

### Exit Criteria
- Users can create, edit, delete profiles
- Users can create recurring schedules attached to profiles
- Scheduled blocks start automatically
- Insights show focus time, blocked attempts, and streaks
- Blocked attempt count updates in real-time during active block

### Estimated complexity: High
### Dependencies: Phase 3 (UI framework), Phase 4 (app picker)

---

## Phase 6: iCloud Sync, Widgets, Command Palette, and System Integration

**Goal:** Cross-device sync, desktop widgets, ⌘K command palette, Shortcuts, Focus mode integration.

### Tasks

- [ ] **6.1** Implement iCloud sync (`iCloudSyncService`):
  - `NSUbiquitousKeyValueStore` for profiles and schedules
  - Encode each profile/schedule as JSON under a UUID key
  - Listen for `didChangeExternallyNotification` → merge into local SwiftData
  - Conflict resolution: last-writer-wins via `updatedAt`
  - Entitlement: `com.apple.developer.ubiquity-kvstore-identifier`
- [ ] **6.2** Implement Desktop Widgets:
  - Small: countdown timer + profile name (or "Ready" + quick-start)
  - Medium: timer + blocked attempts + extend button
  - `TimelineProvider`: read block status from App Group UserDefaults
  - Interactive buttons via App Intents (start profile, extend block)
- [ ] **6.3** Implement Command Palette (⌘K):
  - Overlay view with search field
  - Fuzzy search across: profiles ("Start Work Mode"), actions ("Add domain"), navigation ("Open Insights")
  - Keyboard navigation (up/down arrows, Enter to select)
  - Register global keyboard shortcut ⌘K
- [ ] **6.4** Implement Shortcuts integration (App Intents):
  - `StartBlockIntent`: start a named profile for a duration
  - `StopBlockIntent`: (only works if block has expired — cannot bypass)
  - `GetBlockStatusIntent`: returns remaining time or "no active block"
  - `AddDomainIntent`: add a domain to a profile
  - Register intents for Shortcuts.app and Siri
- [ ] **6.5** Implement Focus mode integration:
  - `IntentConfiguration` tied to macOS Focus modes
  - When user activates a Focus mode (e.g., "Work"), Forge can auto-start the associated profile
  - Settings: map Forge profiles to macOS Focus modes
- [ ] **6.6** Implement remaining keyboard shortcuts:
  - ⌘1-9: quick-start profile 1-9
  - ⌘N: new profile
  - ⌘,: settings
  - ⌘D: edit current profile domains
  - ⌘I: import blocklist
  - ⌘E: export profile
- [ ] **6.7** Implement Notifications:
  - Block started (via schedule): "Work Mode activated — Ends at 5:00 PM"
  - Block ending soon (5 min): "Focus session ends in 5 minutes"
  - Block ended: "Your block has ended. You blocked 47 distractions!"
  - Blocked attempt (optional, off by default): "reddit.com blocked — 1h 22m remaining"
  - App blocked: "Steam can't open during your focus session"
- [ ] **6.8** Write tests:
  - iCloud sync: encode/decode roundtrip, merge conflict resolution
  - Widget timeline provider: active block → correct timeline entries
  - Command palette: fuzzy search ranking, action execution
  - App Intents: start/stop/status intents return correct results

### Exit Criteria
- Profiles and schedules sync across Macs via iCloud
- Desktop widgets show live block status with interactive buttons
- ⌘K palette searches and executes all actions
- Shortcuts.app can start blocks
- macOS Focus modes can trigger Forge profiles
- All keyboard shortcuts functional

### Estimated complexity: High
### Dependencies: Phase 5

---

## Phase 7: Onboarding, Migration, Recovery, and Polish

**Goal:** First-run experience, migration from SelfControl v4, emergency recovery tool, and UI polish.

### Tasks

- [ ] **7.1** Implement Onboarding flow:
  - Step 1: Welcome screen (purpose, commitment model explanation)
  - Step 2: System Extension approval (guided, detect approval, advance automatically)
  - Step 3: First profile (interactive — pick distraction category, preview sites, customize)
  - Step 4: First block (15-minute trial, skippable)
  - Track onboarding completion in UserDefaults
- [ ] **7.2** Implement SelfControl v4 migration:
  - Detect v4 installation (read `NSUserDefaults` for `org.eyebeam.SelfControl`)
  - Import blocklist → create "Migrated" profile
  - Import preferences → map to Forge settings
  - Detect active v4 block → show dialog, let it expire naturally
  - After expiry: remove v4 daemon, helper, PF anchor, hosts entries
- [ ] **7.3** Implement `forge-recovery` CLI:
  - Read manifest from `/Library/Application Support/Forge/manifest.json`
  - Reverse all recorded modifications (PF, pf.conf, cleanup timer)
  - Require `sudo` (root access)
  - Clear error messages for each step
  - Also accessible from Settings → Emergency Recovery in GUI (launches via AuthorizationExecuteWithPrivileges or similar)
- [ ] **7.4** Implement commitment enforcement:
  - During active block: ⌘Q disabled (override `applicationShouldTerminate`)
  - Menu bar "Quit" grayed out
  - Profile cannot be weakened (domains can only be added, not removed)
  - Block can only be extended, not shortened
- [ ] **7.5** UI polish:
  - Animations: spring transitions for block start/end, matched geometry for profile cards
  - Accessibility: VoiceOver labels on all controls, Dynamic Type support
  - Reduce Motion support (check `accessibilityReduceMotion`)
  - Dark mode verification (all screens)
  - Localization setup: String Catalogs (`.xcstrings`) with English base
- [ ] **7.6** Implement browser cache clearing:
  - On block start (if profile option enabled)
  - Clear: Chrome, Safari, Firefox, Opera caches
  - Flush DNS cache: `dscacheutil -flushcache`
- [ ] **7.7** Implement Dock badge (optional):
  - Show countdown HH:MM on Dock icon when enabled
  - Setting: "Show countdown in Dock" (off by default, menu bar is primary)
- [ ] **7.8** Write tests:
  - Onboarding flow UI test
  - Migration: mock v4 defaults, verify profile created
  - Recovery: mock manifest, verify all cleanup steps
  - Commitment: verify ⌘Q blocked during active block

### Exit Criteria
- New users guided through setup smoothly
- SelfControl v4 users can migrate seamlessly
- Emergency recovery works from CLI and GUI
- Active blocks cannot be circumvented via the app
- UI is polished, accessible, and dark-mode correct

### Estimated complexity: High
### Dependencies: Phase 3-6

---

## Phase 8: CI/CD Pipeline, Distribution, and Release

**Goal:** Automated build-test-notarize-distribute pipeline. First public release.

### Tasks

- [ ] **8.1** Complete GitHub Actions release pipeline:
  - Archive release build
  - Export with Developer ID signing
  - Notarize via `xcrun notarytool`
  - Staple notarization ticket
  - Create DMG via `create-dmg`
  - Generate Sparkle appcast
  - Upload to GitHub Releases
  - Trigger on version tag (`v*`)
- [ ] **8.2** Configure Sparkle 2 auto-updates:
  - EdDSA key pair for appcast signing
  - Appcast XML hosted on GitHub Releases
  - In-app update check (manual + automatic)
  - Update UI in Settings
- [ ] **8.3** Configure Sentry crash reporting:
  - SDK integration (opt-in)
  - Settings toggle: "Send anonymized error reports"
  - Breadcrumbs for major operations (block start, extend, end, error)
  - Separate Sentry projects per target (app, extension, helper, CLI)
- [ ] **8.4** Create DMG design:
  - App icon + Applications folder shortcut
  - Background image with Forge branding
- [ ] **8.5** Create landing page / GitHub README:
  - Screenshots
  - Feature highlights
  - Download link
  - Installation instructions
- [ ] **8.6** Final integration testing:
  - Full block lifecycle on clean macOS 15 install
  - Reboot survival test
  - Extension disable bypass test
  - App uninstall during block test
  - Sleep/wake test
  - Recovery tool test
- [ ] **8.7** Performance testing:
  - Measure system impact of NE filter (network latency)
  - Measure system impact of ES AUTH_EXEC (build time comparison)
  - Tune caching and muting thresholds
- [ ] **8.8** Tag v1.0.0 and release

### Exit Criteria
- `git tag v1.0.0 && git push --tags` triggers full pipeline
- DMG is built, notarized, stapled, and uploaded to GitHub Releases
- Sparkle auto-update works from v1.0.0 to v1.0.1
- Sentry receives crash reports (opt-in)
- All system tests pass on clean macOS 15

### Estimated complexity: Medium
### Dependencies: All previous phases

---

## Phase Summary

| Phase | Name | Key Deliverable | Depends On |
|-------|------|----------------|------------|
| 0 | Scaffolding | Xcode project + CI + entitlement requests | — |
| 1 | PF Enforcement | Privileged helper + PF rules + cleanup timer | 0 |
| 2 | Network Extension | DNS proxy + content filter + DoH protection | 0 |
| 3 | Block Engine + UI | Working block lifecycle + minimal SwiftUI | 1, 2 |
| 4 | App Blocking | EndpointSecurity app launch denial | 2, 3 |
| 5 | Profiles & Insights | Multiple profiles, schedules, analytics | 3, 4 |
| 6 | Sync & Integration | iCloud, widgets, ⌘K, Shortcuts, Focus | 5 |
| 7 | Polish & Migration | Onboarding, v4 migration, recovery, a11y | 3-6 |
| 8 | Release | CI/CD, notarization, Sparkle, v1.0.0 | All |

### Parallelization Opportunities

- **Phase 1 and Phase 2 can run in parallel** — they are independent (PF helper vs Network Extension). Different developers can work on each simultaneously.
- **Phase 4 (app blocking) can start as soon as Phase 2's extension infrastructure is in place**, even before Phase 3's UI is complete.
- **Phase 6's sub-tasks are largely independent** — iCloud sync, widgets, command palette, and Shortcuts can be developed in parallel.

### Critical Path

```
Phase 0 → Phase 1 ─┐
                    ├→ Phase 3 → Phase 5 → Phase 6 → Phase 7 → Phase 8
Phase 0 → Phase 2 ─┘        ↗
              └→ Phase 4 ──┘
```

The critical path runs through: **Scaffolding → Network Extension → Block Engine + UI → Profiles → Integration → Polish → Release**. The PF helper and app blocking are off the critical path and can be developed in parallel.

---

## Immediate Next Steps

1. **Create the Xcode project** (Phase 0.1) — this unblocks everything
2. **Submit Apple entitlement requests** (Phase 0.4) — long lead time, do immediately
3. **Start Phase 1 and Phase 2 in parallel** — they are independent
4. **Merge into Phase 3** once both enforcement layers work
