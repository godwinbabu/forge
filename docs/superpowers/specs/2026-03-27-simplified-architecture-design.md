# Forge — Simplified Architecture Design

**Date:** 2026-03-27
**Status:** Approved
**Supersedes:** Sections 4 and 7 of `docs/design-spec.md` (three-layer enforcement → single-layer + friction)

---

## Motivation

The original design used three enforcement layers: Network Extension, PF firewall rules, and a polling cleanup daemon. The PF and daemon layers required a privileged helper installed via `SMJobBless`, which is deprecated since macOS 10.15 with no suitable replacement for unsandboxed root helpers.

This redesign removes the privileged helper, PF rules, cleanup daemon, and all root access. Enforcement relies on the Network Extension as the single blocking layer, with psychological and social friction mechanisms making bypass costly rather than technically impossible.

**Key insight:** No competitor (Freedom, Cold Turkey, Focus, Opal) uses PF firewall rules. They rely on proxy or extension-based blocking and still achieve strong anti-bypass reputations. The commitment mechanism shifts from "technically impossible" to "socially and psychologically difficult."

---

## Architecture

```
Forge.app (SwiftUI, menu bar + window)
    │
    ├── ForgeFilterExtension.systemextension
    │     ├── NEFilterDataProvider  (network traffic filtering)
    │     ├── NEDNSProxyProvider    (DNS interception)
    │     └── EndpointSecurity      (app launch blocking)
    │
    ├── forge-cli (command-line tool)
    │     └── Status queries via shared App Group container
    │
    └── ForgeWidget (WidgetKit extension)
          └── Interactive desktop widgets
```

### Removed from Original Design

- `ForgeHelper` (privileged helper target) — no more root access
- PF firewall anchor rules — no more /etc/pf.conf modification
- Cleanup LaunchDaemon — no more polling daemon
- State manifest at /Library/Application Support/Forge/ — gone
- SMJobBless integration — gone
- Scripts/cleanup.sh — gone

### Single Enforcement Layer

The Network Extension handles all blocking:
- Runs as root (system extension privilege)
- Auto-starts on boot before user login
- Persists ruleset in its own container for reboot survival
- Checks `endDate` on every flow and self-cleans when expired
- Cannot be disabled without deliberate multi-step action in System Settings

---

## Commitment Mechanism (Bypass Friction)

When Forge detects the extension was disabled during an active block, it activates a three-stage friction pipeline.

### Stage 1: Detection & Re-enable Prompt

- App polls `NEFilterManager.shared().isEnabled` every 5 seconds during active blocks
- When disable detected: full-screen modal appears, cannot be dismissed
- Shows: time remaining, blocked attempts so far, motivational message
- Single prominent button: "Re-enable Forge" (opens System Settings to the right pane)
- Modal persists across app restarts (state stored in UserDefaults)

### Stage 2: Typing Challenge

- After 30 seconds, a small "I want to quit" button appears
- Presents a randomized paragraph (80-120 characters) the user must type exactly
- No copy-paste, no autocomplete — character-by-character validation
- Typos reset the entire paragraph
- New random text each attempt
- Example: "I am choosing to end my focus session early. I had 1 hour 23 minutes remaining."

### Stage 3: Cooldown Timer

- After correctly typing the challenge, a 10-minute cooldown begins
- Screen shows countdown with reflection prompt: "Take a moment. What do you actually need right now?"
- User can cancel bypass at any time during cooldown (re-enables the block)
- If they wait the full 10 minutes, the block is officially ended
- Logged as an "early exit" in session history

### Bypass Logging (Always On)

- Every bypass recorded in SwiftData as a `BlockSession` with `trigger: "bypass"`
- Insights view shows: "You ended 2 of 15 sessions early this month"
- Streak tracking penalizes bypasses (streak resets)

### Persistence Across App Quit

If the app is force-quit during an active block with extension disabled, next launch immediately shows the Stage 1 modal. Bypass state is persisted in UserDefaults.

---

## Block Lifecycle

```
START:
  1. User selects profile + duration, taps "Start"
  2. App authenticates via Touch ID / admin password
  3. App builds BlockRuleset from profile
  4. App sends ruleset to Extension via XPC
  5. Extension saves ruleset to its own container (reboot survival)
  6. Extension activates NE filters (DNS proxy + content filter)
  7. App records BlockSession in SwiftData
  8. Block is active

ACTIVE:
  - Extension filters all traffic + blocks app launches
  - App shows countdown in dashboard, menu bar, widget
  - Extension pushes blocked attempt events to app via XPC
  - User can add domains or extend block (never weaken)
  - App polls NEFilterManager.isEnabled every 5 seconds
  - If extension disabled → friction pipeline activates

EXPIRY (normal — app running):
  1. App detects block time reached
  2. App tells Extension: deactivate ruleset
  3. Extension clears in-memory rules + deletes persisted ruleset
  4. App sends notification: "Your block has ended!"
  5. Session recorded with trigger: "completed"

EXPIRY (app not running):
  1. Extension checks endDate on every flow evaluation
  2. If expired: clears rules, deletes persisted ruleset
  3. Extension becomes pass-through
  4. Next app launch: detects block ended, records session

BYPASS (user disables extension):
  1. App detects isEnabled == false
  2. Stage 1: Full-screen re-enable prompt
  3. Stage 2: Typing challenge
  4. Stage 3: 10-minute cooldown
  5. If completed: block ended, session recorded with trigger: "bypass"
  6. If cancelled at any stage: user re-enables, block continues

REBOOT (during active block):
  1. macOS boots
  2. Extension auto-starts, loads persisted ruleset → filtering resumes
  3. When app launches → connects to extension → UI shows active block
```

### App Deletion During Block

If the user deletes Forge.app, the extension is also removed (embedded in app bundle). The block ends. This is a highly deliberate act — well beyond impulsive browsing.

---

## Communication & Data Flow

| From | To | Mechanism | Purpose |
|------|----|-----------|---------|
| App | Extension | XPC (NSXPCConnection via Mach service) | Send ruleset, receive blocked flow events |
| Extension | App | XPC callback (bidirectional) | Push blocked attempt notifications |
| App | Widget | App Group shared container (UserDefaults) | Block status for display |
| App | CLI | App Group shared container (read-only) | Status queries |

### Extension Self-Manages Expiry

- On every `handleNewFlow`, extension checks `endDate` against current time
- If expired: clears ruleset, deletes persisted rules, becomes pass-through
- No external process needed

### App Group (`group.app.forge`) Shared Data

- `isBlockActive: Bool`
- `blockEndDate: Date?`
- `activeProfileName: String?`
- `blockedAttemptCount: Int`
- Written by app, read by widget and CLI

### CLI Is Read-Only in v1

The CLI can query status via the App Group container but cannot start/stop blocks (extension XPC requires the app process). Full CLI control comes for free in Phase 6 when App Intents are built — the CLI invokes intents, the app relays to the extension.

---

## Revised Phase Structure

| Phase | Content | Changed From |
|-------|---------|-------------|
| 0 | Scaffolding (remove ForgeHelper, update project.yml) | Updated |
| 1 | Network Extension — DNS proxy + content filter + reboot persistence | Was Phase 2 |
| 2 | Commitment Mechanism — bypass detection, typing challenge, cooldown, logging | **New** |
| 3 | Block Engine + Basic UI | Was Phase 3 (simplified, no helper XPC) |
| 4 | App Blocking (EndpointSecurity) | Was Phase 4 |
| 5 | Profiles, Scheduling, Insights | Was Phase 5 |
| 6 | iCloud Sync, Widgets, Command Palette, System Integration | Was Phase 6 |
| 7 | Onboarding, Migration, Recovery, Polish | Was Phase 7 (recovery simplified) |
| 8 | CI/CD, Distribution, Release | Was Phase 8 |

### Files Removed

- `ForgeHelper/` directory (HelperMain.swift, HelperDelegate.swift, HelperProtocol.swift, PFManager.swift, ManifestManager.swift, CleanupInstaller.swift, Info.plist)
- `Scripts/cleanup.sh`
- `ForgeHelper` target from `project.yml`
- `Forge/Info.plist` (SMPrivilegedExecutables entry)

### Files Added

- `Forge/Services/BypassDetector.swift` — polls extension status during active blocks
- `Forge/Services/CommitmentEnforcer.swift` — orchestrates the three-stage friction pipeline
- `Forge/Views/Commitment/BypassPromptView.swift` — full-screen re-enable modal
- `Forge/Views/Commitment/TypingChallengeView.swift` — randomized typing test
- `Forge/Views/Commitment/CooldownView.swift` — 10-minute reflection timer

---

## Addendum: PF Enforcement Layer (Future Hardening)

The original three-layer enforcement design is preserved here for potential future implementation. If user feedback indicates the single-layer approach is insufficient, or if Apple provides a non-deprecated replacement for `SMJobBless`, this can be added as an additional hardening phase.

### Original Design Summary

Three independent enforcement layers ensured blocks survived extension disabling, app deletion, and OS updates:

| Layer | Mechanism | What It Catches |
|-------|-----------|----------------|
| 1. System Extension | NE + ES | All traffic, app launches |
| 2. PF Firewall | Kernel packet filter anchor rules | All TCP/UDP by IP (backup if extension disabled) |
| 3. Polling Daemon | LaunchDaemon checks manifest every 30s | OS updates that reset pf.conf, tampering |

### Components Required

**ForgeHelper** — Privileged helper installed via `SMJobBless`:
- Runs unsandboxed as root at `/Library/PrivilegedHelperTools/app.forge.helper`
- XPC protocol: `startEnforcement`, `extendBlock`, `removeEnforcement`, `getStatus`, `getVersion`
- Client code signing validation via `SecCodeCopyGuestWithAttributes`
- Authorization via `AuthorizationRef` (Touch ID / admin password)
- Rate limiting: 3 failed auth attempts in 60s → 5-minute lockout

**PFManager** — PF anchor operations:
- Write anchor rules to `/etc/pf.anchors/app.forge.block`
- Append anchor reference to `/etc/pf.conf`
- Atomic writes: temp → chown root:wheel → chmod 644 → rename
- Reload via `pfctl -E -f /etc/pf.conf`
- Remove: strip anchor lines, flush anchor, delete file
- Verify: `pfctl -a app.forge.block -sr`

**ManifestManager** — State manifest:
```swift
struct SystemStateManifest: Codable {
    let version: Int = 1
    let blockID: UUID
    let createdAt: Date
    let blockEndDate: Date
    let blockEndDateEpoch: Int
    var pfAnchorInstalled: Bool
    var pfAnchorPath: String
    var cleanupTimerInstalled: Bool
    var cleanupTimerPlistPath: String
    var blockedDomains: [String]
    var blockedIPs: [String]
    var blockMode: String
    var allowLocalNetwork: Bool
}
```
- Location: `/Library/Application Support/Forge/manifest.json`
- Root-owned, world-readable (0644), written atomically

**CleanupInstaller** — LaunchDaemon timer:
- Plist at `/Library/LaunchDaemons/app.forge.cleanup.plist`
- `StartInterval: 30` (polls every 30 seconds)
- Script checks manifest expiry → strips pf.conf → flushes anchor → self-removes
- If block active and anchor missing → re-adds (OS update resilience)

### Why Deferred

`SMJobBless` is deprecated since macOS 10.15. `SMAppService.daemon()` requires sandboxing on macOS 14.2+, which prevents modifying `/etc/pf.conf`. No current Apple API supports unsandboxed root helpers. If Apple provides a replacement, this layer can be added without changing the rest of the architecture.
