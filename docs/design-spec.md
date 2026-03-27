# Forge — Design Specification

> *Forge your focus. Block distractions. No compromises.*
>
> Forge is the successor to SelfControl, rebuilt from the ground up for modern macOS.

**Date:** 2026-03-27
**Status:** Draft — Pending Review
**Target:** macOS 15+ (Sequoia), Liquid Glass ready for macOS 26 (Tahoe)
**Language:** Swift, SwiftUI
**Distribution:** Direct download (Developer ID, notarized), Sparkle auto-updates

---

## Table of Contents

1. [Background & Motivation](#1-background--motivation)
2. [Product Vision](#2-product-vision)
3. [Feature Inventory](#3-feature-inventory)
4. [System Architecture](#4-system-architecture)
5. [Network Filtering Engine](#5-network-filtering-engine)
6. [App Blocking Engine](#6-app-blocking-engine)
7. [Privileged Helper & Enforcement Backbone](#7-privileged-helper--enforcement-backbone)
8. [Data Model, Profiles & Scheduling](#8-data-model-profiles--scheduling)
9. [UI & User Experience](#9-ui--user-experience)
10. [Testing Strategy](#10-testing-strategy)
11. [CI/CD & Distribution](#11-cicd--distribution)
12. [Project Structure](#12-project-structure)
13. [Competitive Landscape](#13-competitive-landscape)
14. [Migration from v4](#14-migration-from-v4)
15. [Risks & Open Questions](#15-risks--open-questions)
16. [Appendices](#16-appendices)

---

## 1. Background & Motivation

### What is SelfControl?

SelfControl is a free, open-source macOS application that blocks access to distracting websites and services for a set period of time. Once a block is started, it cannot be undone — not by restarting the app, not by restarting the computer, not by deleting the app. This "unbypassable commitment" is SelfControl's defining feature and core brand promise.

The project was created in 2009 and has been actively maintained since. It is written in Objective-C and uses a privileged daemon (running as root) to enforce blocks via two mechanisms: modifying the system hosts file (`/etc/hosts`) and installing packet filter (pf) firewall rules.

### Why a Complete Rewrite?

The current codebase (v4.0.2) has accumulated significant technical debt:

- **Deployment target is macOS 10.10** (Yosemite, 2014) — blocks adoption of any modern APIs
- **Objective-C with XIB-based UI** — no path to SwiftUI, Liquid Glass, or modern macOS design
- **Hosts file blocking is trivially bypassed** by any browser using DNS-over-HTTPS (DoH) — Chrome, Firefox, and Safari all support DoH, rendering the primary blocking mechanism ineffective
- **No app sandbox, no notarization pipeline** — users on modern macOS see security warnings
- **Single global blocklist** with no profiles, schedules, or analytics
- **< 5% test coverage**, no CI/CD pipeline
- **All dependencies outdated** (Sentry 7.x, unmaintained CocoaPods libraries)
- **Thread safety issues** throughout the codebase (unsynchronized shared state, potential deadlocks)
- **Non-atomic system file modifications** that can corrupt `/etc/hosts` or `/etc/pf.conf`

A detailed architectural review is available at `rearchitect/architectural-review.md`.

### Goals for v5

1. **Modern blocking that defeats DoH** — use Apple's Network Extension framework to intercept traffic at the socket level
2. **Block apps, not just websites** — prevent distracting applications from launching
3. **Profiles and schedules** — multiple named blocking configurations with recurring automation
4. **Usage insights** — show users how much time they saved and what they blocked
5. **Cross-device sync** — sync profiles and schedules across Macs via iCloud
6. **Modern macOS UX** — SwiftUI, menu bar-first, keyboard-driven, widgets, Liquid Glass ready
7. **Preserve the core promise** — blocks remain genuinely unbypassable via a multi-layer enforcement architecture
8. **Clean system restoration** — every system modification is tracked and reversible
9. **Automated CI/CD** — GitHub Actions for build, test, notarize, and distribute

---

## 2. Product Vision

Forge is a **menu bar-first focus tool** for macOS that blocks distracting websites and apps with an unbypassable commitment mechanism. It combines:

- **Hard blocking** (sites and apps are genuinely inaccessible) with
- **Smart profiles** (pre-configured blocking sets for work, study, etc.) and
- **Automated schedules** (blocks start automatically on a recurring basis)

The app is privacy-first (all data local, optional iCloud sync, optional crash reporting), designed for power users who value keyboard shortcuts and system integration, and visually native to macOS with Liquid Glass support.

### What Forge is NOT

- Not a parental control tool (it's self-imposed)
- Not a time tracker (it shows focus insights, not detailed app usage logs)
- Not a subscription service (monetization model TBD, but architecture supports free/freemium/one-time purchase)
- Not cross-platform (macOS only, leverages deep OS integration)

---

## 3. Feature Inventory

### Preserved from v4

All existing user-facing features are carried forward:

| Feature | v4 Implementation | v5 Implementation |
|---------|-------------------|-------------------|
| Website blocking (blocklist mode) | Hosts file + PF rules | Network Extension + PF backup |
| Website blocking (allowlist mode) | Hosts file + PF rules | Network Extension + PF backup |
| Unbypassable commitment | Daemon re-applies rules | Three independent enforcement layers |
| Block duration slider | NSSlider in XIB | SwiftUI slider |
| Timer countdown display | Custom timer window | Dashboard + menu bar + widget |
| Add domain during block | Modal sheet | Inline in dashboard + ⌘K palette |
| Extend block duration | Modal sheet | Inline in dashboard + ⌘K palette |
| Import/export blocklists | .selfcontrol plist files | JSON profile export/import |
| Preset domain lists | "Common Distracting Sites" | Built-in profile templates |
| Common subdomain expansion | www.* variant blocking | Configurable per profile |
| Local network exemption | AllowLocalNetworks setting | Configurable per profile |
| Browser cache clearing | Clears Chrome/Safari/Firefox caches | Configurable per profile |
| Block sound on completion | System sound selection | System notification with optional sound |
| Dock badge countdown | Custom dock tile | Optional, preserved |
| CLI tool | forge-cli | Swift ArgumentParser CLI |
| Touch ID authentication | Via Security framework | Via LocalAuthentication + XPC |
| Localization (13 languages) | .lproj directories | String Catalogs (.xcstrings) |
| Auto-updates | Sparkle 1.x | Sparkle 2 (EdDSA) |
| Crash reporting | Sentry (opt-in) | Sentry latest (opt-in) |
| Emergency block recovery | SelfControl Killer app | forge-recovery CLI + in-app |

### New in v5

| Feature | Description |
|---------|-------------|
| **App blocking** | Prevent macOS apps from launching during a block (via EndpointSecurity or NSWorkspace fallback) |
| **DoH/DoT bypass protection** | Block connections to known DNS-over-HTTPS servers, forcing browsers to use system DNS which we control |
| **Profiles** | Multiple named blocking configurations (sites + apps + settings) |
| **Built-in presets** | Social Media, News & Media, Gaming, Focus Mode — ready to use out of the box |
| **Recurring schedules** | Attach profiles to weekly schedules (e.g., "Work Mode M-F 9-5") |
| **Usage insights** | Focus time, blocked attempt counts, most-blocked sites, streak tracking — all via Swift Charts |
| **Cross-device sync** | Profiles and schedules sync across Macs via iCloud (NSUbiquitousKeyValueStore) |
| **Menu bar interface** | Primary interaction via menu bar popover — quick status, quick-start profiles |
| **Desktop widgets** | Interactive WidgetKit widgets — countdown timer, quick-start, stats |
| **Command palette** | ⌘K to search and execute any action (start profiles, add domains, navigate) |
| **Shortcuts integration** | Start/stop blocks via Shortcuts.app and App Intents |
| **Focus mode integration** | Tie Forge profiles to macOS Focus modes |
| **State manifest** | Every system modification tracked in a manifest for guaranteed clean restoration |
| **Recovery CLI** | `forge-recovery --force` reads manifest and undoes all system changes |

### Deferred (architecture supports, not in v1)

| Feature | Notes |
|---------|-------|
| Content-based blocking | Block pages by topic/keywords — requires browser extension for HTTPS content on macOS |
| Friction/mindfulness mode | Breathing exercise delay before allowing access (like One Sec) |
| Focus sounds | Ambient audio during blocks |
| Mac App Store distribution | Possible with Network Extension approach, deferred |

---

## 4. System Architecture

### Overview

Four components, each with a single responsibility:

```
Forge.app (SwiftUI, menu bar + window)
    │
    ├── ForgeFilterExtension.systemextension
    │     ├── NEFilterDataProvider  (network traffic filtering)
    │     ├── NEDNSProxyProvider    (DNS interception)
    │     └── EndpointSecurity      (app launch blocking)
    │
    ├── ForgeHelper (XPC service, runs as root)
    │     ├── PF anchor management
    │     ├── pf.conf modification
    │     ├── Cleanup timer installation
    │     └── State manifest management
    │
    ├── forge-cli (command-line tool)
    │     └── Same XPC interfaces as GUI app
    │
    └── ForgeWidget (WidgetKit extension)
          └── Interactive desktop widgets
```

### Why Three Enforcement Layers?

Forge's core promise is that blocks cannot be bypassed. A single enforcement mechanism can always be circumvented (disable the extension, uninstall the app, etc.). Three independent layers ensure the block holds:

| Layer | Mechanism | What it catches | Can user disable? |
|-------|-----------|----------------|-------------------|
| **1. System Extension** | NEFilterDataProvider + NEDNSProxyProvider + EndpointSecurity | All traffic (including DoH), app launches | Yes — via System Settings |
| **2. PF Firewall** | Packet filter anchor rules in kernel | All TCP/UDP by IP | No — requires root, survives app deletion |
| **3. Polling Daemon** | LaunchDaemon checks manifest, re-applies PF if missing | OS updates that reset pf.conf, tampering | No — root-owned, self-removing at expiry |

If the user disables the System Extension, PF rules still block traffic. If an OS update resets pf.conf, the polling daemon re-applies the anchor. All three layers self-clean when the block expires.

### Communication Between Components

| From | To | Mechanism | Purpose |
|------|----|-----------|---------|
| App | System Extension | XPC (NSXPCConnection via Mach service) | Send ruleset, receive blocked flow events |
| App | Privileged Helper | XPC (NSXPCConnection, authorized) | Write PF rules, install timer, manage manifest |
| App | Widget | App Group shared container | Block status, profile data for display |
| System Extension | App | XPC callback (bidirectional on same connection) | Push blocked attempt notifications |
| CLI | System Extension | Same XPC as app | Start/stop/query blocks |
| CLI | Privileged Helper | Same XPC as app | Same operations as GUI |
| Polling Daemon | Manifest file | File read | Check block expiry, re-apply PF if needed |

**Important constraint:** The System Extension runs as root and the app runs as the logged-in user. They **cannot** share an App Group container (different filesystem paths due to different UIDs). All communication between them must go through XPC. The extension persists its active ruleset in its own root-owned container for reboot survival.

### Block Lifecycle

```
START:
  1. User selects profile + duration, taps "Start"
  2. App authenticates via Touch ID / admin password
  3. App encodes ruleset from profile (domains, IPs, app bundle IDs)
  4. App sends ruleset to System Extension via XPC
  5. Extension saves ruleset to its own container (for reboot survival)
  6. Extension activates NE filters (DNS proxy + content filter) + ES app blocking
  7. App sends manifest data to Privileged Helper via XPC
  8. Helper writes PF anchor to /etc/pf.anchors/app.forge.block
  9. Helper appends anchor reference to /etc/pf.conf (with identifier for later removal)
  10. Helper reloads pf: pfctl -E -f /etc/pf.conf
  11. Helper installs cleanup LaunchDaemon (polls every 30s, checks expiry)
  12. Helper writes manifest.json to /Library/Application Support/Forge/
  13. App records BlockSession in SwiftData (for analytics)
  14. Block is active — three layers operational

ACTIVE:
  - System Extension filters all traffic + blocks app launches
  - Cleanup daemon polls every 30s: checks manifest, re-applies PF if missing
  - App shows countdown in dashboard, menu bar, and widget
  - Extension pushes blocked attempt events to app via XPC callback
  - User can add domains or extend block (only strengthen, never weaken)

EXPIRY:
  Path A (app is running):
    1. App detects block expired
    2. App tells Extension: deactivate ruleset → Extension clears in-memory rules + deletes persisted ruleset
    3. App tells Helper: removeEnforcement() → Helper strips pf.conf, flushes anchor, deletes manifest
    4. Cleanup daemon detects manifest gone → self-removes
    5. App sends notification: "Your block has ended!"

  Path B (app not running — cleanup daemon handles it):
    1. Daemon polls, reads manifest, sees blockEndDate has passed
    2. Daemon strips anchor reference from pf.conf
    3. Daemon flushes PF anchor: pfctl -a app.forge.block -F all
    4. Daemon deletes anchor file, manifest, and its own LaunchDaemon plist
    5. Daemon runs: launchctl bootout system/app.forge.cleanup
    6. System Extension's persisted ruleset has the same endDate — on next startFilter(),
       it checks expiry and clears itself

  Path C (emergency recovery):
    1. User runs: sudo forge-recovery --force
    2. Tool reads manifest.json
    3. Reverses every recorded modification
    4. System restored to prior state

REBOOT (during active block):
  1. macOS boots
  2. System Extension auto-starts (user-approved, before login)
     → startFilter() → loads persisted ruleset → filtering resumes
  3. PF rules active (anchor reference in pf.conf, loaded on boot)
  4. Cleanup daemon starts → reads manifest → block not expired → continues polling
  5. All three layers operational without app running
  6. When app eventually launches → connects to extension via XPC → UI shows active block
```

---

## 5. Network Filtering Engine

The System Extension (`ForgeFilterExtension.systemextension`) contains two network providers that work together:

### NEDNSProxyProvider — DNS Interception

Intercepts all DNS queries routed through the system resolver:

- Receives every standard DNS lookup (port 53) before it leaves the machine
- Checks queried domain against active ruleset
- **Blocked domain:** Returns `0.0.0.0` / `::` (NXDOMAIN-like response)
- **Allowed domain:** Forwards to upstream resolver, records IP→hostname mapping
- The IP→hostname mapping is shared with the content filter (see below) to identify flows from browsers that resolve DNS independently

**Limitation (verified):** NEDNSProxyProvider does NOT intercept DNS-over-HTTPS (DoH) queries made by browsers internally (Chrome, Firefox). Those appear as regular HTTPS connections. This is handled by the content filter below.

### NEFilterDataProvider — Traffic Filter

Inspects all network flows at the socket level:

**Primary responsibilities:**
1. **Domain blocking via hostname:** Check `NEFilterSocketFlow.remoteHostname` against ruleset → drop if blocked
2. **IP-based blocking:** When `remoteHostname` is nil (Chrome and Chromium-based browsers resolve DNS independently and connect by IP), use the IP→hostname mapping from the DNS proxy to identify the destination
3. **SNI inspection fallback:** For flows where both hostname and IP mapping are unavailable, inspect the TLS ClientHello SNI bytes in `handleOutboundData` to extract the destination hostname
4. **DoH server blocking:** Block connections to known DoH resolver IPs (1.1.1.1, 8.8.8.8, 8.8.4.4, dns.google, cloudflare-dns.com, dns.quad9.net, etc.) — forces browsers to fall back to system DNS, which we control via the DNS proxy
5. **Allowlist mode:** Drop all flows except those matching allowed domains/IPs. Default allow rules for essential services: DNS (53), NTP (123), DHCP (67-68), mDNS (5353)

**Why two providers?**

| Concern | DNS Proxy alone | Content Filter alone | Both together |
|---------|----------------|---------------------|---------------|
| Standard DNS blocking | Yes | No (only sees connections) | Yes |
| DoH bypass protection | No | Yes (blocks DoH server IPs) | Yes |
| IP-based blocking | No | Yes | Yes |
| Hostname for Chrome flows | No | No (remoteHostname is nil) | Yes — DNS proxy builds IP→hostname map |
| Future content inspection | No | Yes | Yes |
| Performance | Fast (DNS only) | Heavier (all flows) | DNS handles 95% fast, filter handles edge cases |

### Ruleset Format

Rules are delivered to the extension from the app via XPC and persisted in the extension's own container for reboot survival:

```swift
struct BlockRuleset: Codable {
    let id: UUID
    let mode: BlockMode                  // .blocklist or .allowlist
    let domains: [DomainRule]            // website rules
    let appBundleIDs: [String]           // for EndpointSecurity (passed through)
    let dohServerIPs: [String]           // known DoH resolver IPs to block
    let allowLocalNetwork: Bool
    let expandCommonSubdomains: Bool     // auto-add www.*, m.*, etc.
    let startDate: Date
    let endDate: Date
}

enum DomainRule: Codable {
    case exact(String)                   // "reddit.com"
    case wildcard(String)                // "*.reddit.com"
    case cidr(String, Int)               // "192.168.1.0", mask 24
    case portSpecific(String, Int)       // "example.com", port 8080
}

enum BlockMode: String, Codable {
    case blocklist    // block these, allow everything else
    case allowlist    // allow these, block everything else
}
```

### Extension Lifecycle

```swift
class FilterDataProvider: NEFilterDataProvider {
    private var activeRuleset: BlockRuleset?

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        // Called by macOS on boot (auto-start) or first activation
        if let saved = RulesetStore.load() {
            if saved.endDate > Date() {
                activeRuleset = saved
                applyFilterSettings()
            } else {
                // Block expired while system was off — clean up
                RulesetStore.delete()
            }
        }
        completionHandler(nil)
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let ruleset = activeRuleset else { return .allow() }

        // Check if block has expired
        if Date() >= ruleset.endDate {
            activeRuleset = nil
            RulesetStore.delete()
            return .allow()
        }

        let hostname = resolveHostname(for: flow)  // remoteHostname, IP map, or SNI

        switch ruleset.mode {
        case .blocklist:
            return ruleset.matches(hostname) ? .drop() : .allow()
        case .allowlist:
            return ruleset.matches(hostname) ? .allow() : .drop()
        }
    }
}
```

### Future: Content-Based Blocking

`NEFilterDataProvider` on macOS **cannot** inspect decrypted HTTPS content (unlike iOS where it can see WebKit traffic). For future content-based blocking (e.g., "block pages about gambling"), the architecture supports adding a **browser extension** that:
- Inspects page content inside the browser
- Communicates with the system extension via native messaging
- The system extension makes the allow/block decision

This is a deferred feature — the architecture accommodates it without changes.

---

## 6. App Blocking Engine

### Primary Mechanism: EndpointSecurity

The `EndpointSecurity` framework provides kernel-level process execution control. We subscribe to `ES_EVENT_TYPE_AUTH_EXEC` events and deny launches of blocked apps before they start.

**How it works:**
1. Extension registers an ES client on startup
2. Subscribes to `AUTH_EXEC` events
3. For each exec event, extracts the executable path and resolves the bundle ID
4. Checks bundle ID against `activeRuleset.appBundleIDs`
5. Returns `ES_AUTH_RESULT_DENY` for blocked apps, `ES_AUTH_RESULT_ALLOW` for everything else
6. macOS shows the user a native "This application can't be opened" dialog

**Performance mitigations (critical):**
- Cache `ES_AUTH_RESULT_ALLOW` for all non-blocked executables — vast majority of exec events
- Mute trusted processes aggressively via `es_mute_process()` — compilers, system daemons, shells
- Respond in <1ms (simple set membership check, no I/O)
- Muting prevents measurable system slowdown for development workflows (builds, tests)

**Apps already running when block starts:** Sent `SIGTERM` (graceful quit). If still running after 5 seconds, sent `SIGKILL`.

**Protected apps (never blocked):** Finder, System Settings, loginwindow, SecurityAgent, Terminal (needed for recovery), and the Forge app itself.

### Entitlement Requirement & Risk

EndpointSecurity requires the `com.apple.developer.endpoint-security.client` entitlement, which must be approved by Apple. This is a restricted entitlement — approval is not guaranteed.

**Fallback mechanism:** If the entitlement is not granted, app blocking falls back to `NSWorkspace.didLaunchApplicationNotification` + process termination. This is reactive (app briefly appears then is killed) rather than preventive (app never launches), but requires no special entitlement.

Both implementations conform to the same protocol, making the switch transparent:

```swift
protocol AppBlocker {
    func blockApps(_ bundleIDs: Set<String>)
    func unblockAll()
}

class EndpointSecurityAppBlocker: AppBlocker { ... }  // Primary
class WorkspaceAppBlocker: AppBlocker { ... }          // Fallback
```

### Coexistence with Network Extension

EndpointSecurity and NEFilterDataProvider **can** coexist in a single System Extension. The extension's `Info.plist` declares separate Mach service names for each:
- `NSEndpointSecurityMachServiceName` for ES
- `NEMachServiceName` under the `NetworkExtension` dictionary for NE

This is verified as supported by Apple (developer forums and WWDC sessions).

---

## 7. Privileged Helper & Enforcement Backbone

### Purpose

The privileged helper is the layer that makes blocks **survive extension disabling, app deletion, and reboots**. It runs as root and manages system-level enforcement that persists independently of the app and extension.

### Installation

Installed via **`SMJobBless`** (not `SMAppService`). This is the legacy API, but it's required because:
- `SMAppService` daemons must be sandboxed (macOS 14.2+), which prevents modifying system files
- `SMJobBless` copies the helper to `/Library/PrivilegedHelperTools/` where it runs unsandboxed as root
- The helper binary **survives app deletion** — it persists at `/Library/PrivilegedHelperTools/app.forge.helper`
- This means the cleanup timer and PF rules remain active even if the user deletes Forge.app during a block

### XPC Interface

```swift
@objc protocol ForgeHelperProtocol {
    func startEnforcement(
        manifest: Data,          // encoded SystemStateManifest
        authorization: Data,     // AuthorizationExternalForm
        reply: @escaping (Error?) -> Void
    )

    func extendBlock(
        newEndDate: Date,
        authorization: Data,
        reply: @escaping (Error?) -> Void
    )

    func removeEnforcement(
        reply: @escaping (Error?) -> Void
    )

    func getStatus(
        reply: @escaping (Data?) -> Void  // encoded manifest or nil
    )

    func getVersion(
        reply: @escaping (String) -> Void
    )
}
```

### XPC Security

| Measure | Implementation |
|---------|---------------|
| Client code signing validation | `SecCodeCopyGuestWithAttributes` from `auditToken`, verify team ID + minimum version |
| Authorization | Touch ID / admin password via `AuthorizationRef` (2-minute timeout) |
| Rate limiting | 3 failed auth attempts in 60s → 5-minute lockout |
| Connection handling | Async `Task` for invalidation (avoids `dispatch_sync` deadlock from v4) |

### PF Anchor Strategy

The helper **must** modify `/etc/pf.conf` because PF anchors require an explicit reference in a parent ruleset to be evaluated. However, modifications are minimal and clean:

**Install:**
```bash
# 1. Write block rules to anchor file
/etc/pf.anchors/app.forge.block

# 2. Append to /etc/pf.conf (identifiable by anchor name, no markers needed):
anchor "app.forge.block"
load anchor "app.forge.block" from "/etc/pf.anchors/app.forge.block"

# 3. Set correct permissions on temp file before atomic rename
chown root:wheel /etc/pf.conf.tmp && chmod 644 /etc/pf.conf.tmp
rename("/etc/pf.conf.tmp", "/etc/pf.conf")

# 4. Reload: pfctl -E -f /etc/pf.conf
```

**Remove:**
```bash
# 1. Strip lines containing "app.forge.block" from /etc/pf.conf
# 2. Flush anchor: pfctl -a app.forge.block -F all
# 3. Delete anchor file: rm /etc/pf.anchors/app.forge.block
# 4. Reload: pfctl -f /etc/pf.conf
```

**OS update resilience:** macOS updates can overwrite `/etc/pf.conf`, removing our anchor reference. The cleanup daemon (see below) detects this and re-adds the reference while the block is active.

### Cleanup Timer (LaunchDaemon)

A polling daemon that ensures the block expires and cleans up, regardless of whether the app is running:

```xml
<!-- /Library/LaunchDaemons/app.forge.cleanup.plist -->
<dict>
    <key>Label</key>
    <string>app.forge.cleanup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Library/Application Support/Forge/cleanup.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>30</integer>  <!-- polls every 30 seconds -->
    <key>RunAtLoad</key>
    <true/>
</dict>
```

**Why `StartInterval` (polling) instead of `StartCalendarInterval` (one-shot)?**
- `StartCalendarInterval` has no Year field — it creates a recurring annual event, not a one-shot
- If the Mac is powered off at the scheduled time, the event is **missed entirely** (not fired on next boot)
- `StartInterval` + timestamp check handles all edge cases: sleep, power-off, time zone changes

**cleanup.sh logic:**
```bash
#!/bin/bash
MANIFEST="/Library/Application Support/Forge/manifest.json"
[ ! -f "$MANIFEST" ] && exit 0  # No manifest = nothing to do

END_DATE=$(jq -r '.blockEndDateEpoch' "$MANIFEST")
NOW=$(date +%s)

if [ "$NOW" -ge "$END_DATE" ]; then
    # Block expired — clean up everything
    pfctl -a app.forge.block -F all
    sed -i '' '/app.forge.block/d' /etc/pf.conf
    pfctl -f /etc/pf.conf
    rm -f /etc/pf.anchors/app.forge.block
    rm -f "$MANIFEST"
    rm -f "/Library/Application Support/Forge/cleanup.sh"
    rm -f /Library/LaunchDaemons/app.forge.cleanup.plist
    launchctl bootout system/app.forge.cleanup
else
    # Block still active — verify PF rules are in place
    if ! grep -q "app.forge.block" /etc/pf.conf; then
        # Anchor reference missing (OS update?) — re-add it
        echo 'anchor "app.forge.block"' >> /etc/pf.conf
        echo 'load anchor "app.forge.block" from "/etc/pf.anchors/app.forge.block"' >> /etc/pf.conf
        pfctl -E -f /etc/pf.conf
    fi
fi
```

### State Manifest

The single source of truth for what the helper has modified:

```swift
struct SystemStateManifest: Codable {
    let version: Int = 1
    let blockID: UUID
    let createdAt: Date
    let blockEndDate: Date
    let blockEndDateEpoch: Int         // Unix timestamp for shell script

    var pfAnchorInstalled: Bool
    var pfAnchorPath: String           // /etc/pf.anchors/app.forge.block
    var cleanupTimerInstalled: Bool
    var cleanupTimerPlistPath: String  // /Library/LaunchDaemons/app.forge.cleanup.plist

    // Block parameters for re-application on integrity check
    var blockedDomains: [String]
    var blockedIPs: [String]
    var blockMode: String              // "blocklist" or "allowlist"
    var allowLocalNetwork: Bool
}
```

**Location:** `/Library/Application Support/Forge/manifest.json`
- Root-owned (written by helper), world-readable (0644)
- Written atomically (temp + rename with chown/chmod)
- Read by: app, CLI, cleanup daemon, recovery tool
- Written by: helper only

### Recovery CLI

Emergency escape hatch that reads the manifest and reverses everything:

```bash
$ sudo forge-recovery --force

Reading manifest from /Library/Application Support/Forge/manifest.json
Block ID: 3F2A7C... (expires 2026-03-27 17:00:00)
Reversing system modifications:
  Flushed PF anchor app.forge.block
  Stripped anchor reference from /etc/pf.conf
  Removed /etc/pf.anchors/app.forge.block
  Removed cleanup timer
  Deleted manifest
System restored to prior state.
```

---

## 8. Data Model, Profiles & Scheduling

### Storage Architecture

Three storage layers, each for a different purpose:

```
┌──────────────────────────────────────────────┐
│  iCloud (NSUbiquitousKeyValueStore)          │
│  Profiles + schedules sync across Macs       │
│  Limit: 1 MB total / 1024 keys (sufficient) │
│  Entitlement: ubiquity-kvstore-identifier    │
│  No sandbox required                         │
└──────────────┬───────────────────────────────┘
               │ automatic sync
┌──────────────▼───────────────────────────────┐
│  App Group Container (user-owned)            │
│  ~/Library/Group Containers/<group-id>/      │
│  ├── SwiftData DB (profiles, schedules,      │
│  │                  sessions/history)         │
│  └── UserDefaults (UI state, preferences)    │
│                                              │
│  Accessed by: App, CLI, Widget (same user)   │
│  NOT accessed by: System Extension or Helper  │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  System Extension Container (root-owned)     │
│  /private/var/root/Library/.../              │
│  └── active-ruleset.json                     │
│                                              │
│  Written by extension when it receives       │
│  a ruleset via XPC. Read on startFilter()    │
│  after reboot. Self-cleaning on expiry.      │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│  /Library/Application Support/Forge/   │
│  ├── manifest.json                           │
│  └── cleanup.sh                              │
│                                              │
│  Root-owned. Written by Privileged Helper.   │
│  World-readable. Self-cleaning on expiry.    │
└──────────────────────────────────────────────┘
```

**Key constraint (verified):** The System Extension runs as root and the app runs as the logged-in user. Even with the same App Group identifier, they get **different container paths** (`/private/var/root/...` vs `~/Library/...`). All app↔extension communication goes through XPC. The extension maintains its own persistent storage for reboot survival.

### Core Data Model (SwiftData)

```swift
@Model
class BlockProfile {
    let id: UUID
    var name: String                    // "Work Mode", "Study", "Sleep"
    var icon: String                    // SF Symbol name
    var color: String                   // Hex color for UI
    var mode: BlockMode                 // .blocklist or .allowlist
    var domains: [String]               // Sites to block/allow
    var appBundleIDs: [String]          // Apps to block
    var allowLocalNetwork: Bool
    var expandCommonSubdomains: Bool
    var clearCaches: Bool
    var createdAt: Date
    var updatedAt: Date

    var schedules: [BlockSchedule]      // Relationship
    var sessions: [BlockSession]        // Relationship (history)
}

@Model
class BlockSchedule {
    let id: UUID
    var profile: BlockProfile?          // Optional relationship
    var weekdays: [Int]                 // 1=Sun, 2=Mon, ... 7=Sat
    var startHour: Int                  // 0-23
    var startMinute: Int                // 0-59
    var endHour: Int
    var endMinute: Int
    var enabled: Bool
    var createdAt: Date
}

@Model
class BlockSession {
    let id: UUID
    var profileID: UUID?                // nil for ad-hoc blocks
    var profileName: String?            // Snapshot (profile may be deleted)
    var startDate: Date
    var endDate: Date
    var actualEndDate: Date?            // nil if still active
    var domains: [String]               // Snapshot at block start
    var appBundleIDs: [String]
    var mode: String                    // "blocklist" or "allowlist"
    var blockedAttemptCount: Int        // Updated during block
    var wasExtended: Bool
    var wasKilled: Bool                 // Emergency recovery used
    var triggeredBy: String             // "manual", "schedule", "cli"
}
```

### Profiles

| Feature | Description |
|---------|-------------|
| Multiple profiles | Users create named blocking configurations |
| Per-profile settings | Each profile has its own domains, apps, mode, and options |
| Built-in presets | Social Media, News & Media, Gaming, Focus Mode — pre-populated, editable |
| Import/Export | JSON format, replaces legacy .selfcontrol plist |
| One-click activation | Tap a profile card → authenticate → block starts |

### Scheduling Engine

A lightweight evaluator runs in the app (or its menu bar agent) every 30 seconds:

```swift
func evaluateSchedules() {
    let now = Date()
    let calendar = Calendar.current
    let currentWeekday = calendar.component(.weekday, from: now)
    let currentHour = calendar.component(.hour, from: now)
    let currentMinute = calendar.component(.minute, from: now)
    let currentMinutes = currentHour * 60 + currentMinute

    for schedule in enabledSchedules {
        guard schedule.weekdays.contains(currentWeekday) else { continue }
        guard !blockIsActiveForProfile(schedule.profile) else { continue }

        let startMinutes = schedule.startHour * 60 + schedule.startMinute
        let endMinutes = schedule.endHour * 60 + schedule.endMinute

        if endMinutes > startMinutes {
            // Same-day schedule (e.g., 9:00 AM → 5:00 PM)
            if currentMinutes >= startMinutes && currentMinutes < endMinutes {
                startBlock(profile: schedule.profile, endMinutes: endMinutes)
            }
        } else {
            // Overnight schedule (e.g., 10:00 PM → 6:00 AM)
            if currentMinutes >= startMinutes || currentMinutes < endMinutes {
                startBlock(profile: schedule.profile, endMinutes: endMinutes)
            }
        }
    }
}
```

**Edge cases:**

| Scenario | Behavior |
|----------|----------|
| Schedule spans midnight (10 PM → 6 AM) | Split check: current ≥ start OR current < end |
| Mac asleep during start time | On wake, evaluator runs, starts block for remaining window |
| Mac off during entire window | Missed — no retroactive blocking |
| Manual block overlaps schedule | Longer of the two durations wins |
| User extends a scheduled block | Extension honored, `actualEndDate` updated |

### iCloud Sync

Profiles and schedules sync across the user's Macs via `NSUbiquitousKeyValueStore`:

```swift
// Write: encode profile as JSON, store under profile-specific key
let data = try JSONEncoder().encode(profile)
let store = NSUbiquitousKeyValueStore.default
store.set(data, forKey: "profile-\(profile.id.uuidString)")

// Read: decode on change notification
NotificationCenter.default.addObserver(
    forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
    ...
) { notification in
    // Merge remote changes into local SwiftData
}
```

| Data | Syncs via iCloud? | Reason |
|------|-------------------|--------|
| Profiles | Yes | Same blocking config on all Macs |
| Schedules | Yes | Same recurring schedule everywhere |
| Block sessions (history) | Yes | Unified insights across devices |
| Active block state | No | Enforcement is per-machine |
| System manifest | No | Machine-specific, root-owned |

**Conflict resolution:** Last-writer-wins using `updatedAt` timestamp. `NSUbiquitousKeyValueStore` handles this automatically per key.

**Size budget:** A profile with 100 domains, name, icon, color, and settings is ~5 KB. 100 profiles + schedules + session history fits well within the 1 MB limit.

---

## 9. UI & User Experience

### Design Philosophy

- **Menu bar-first:** The app lives in the menu bar. The full window is for configuration, not daily use.
- **Keyboard-first:** Every action reachable via keyboard. ⌘K command palette for power users.
- **macOS-native:** NavigationSplitView, SF Symbols, system colors, Dark Mode automatic. Liquid Glass ready via standard SwiftUI components (glass sidebar, toolbar, materials recompiled with Xcode 26).
- **Privacy-first:** All analytics local. No data sent anywhere except optional Sentry crash reports and optional iCloud sync.
- **Anti-gamification:** Insights are informational, not competitive. No leaderboards, no points. Streak counter is present but subtle.
- **Commitment integrity:** During active block: app cannot be quit (⌘Q disabled), profile cannot be weakened (only extended/strengthened), menu bar quit grayed out.

### App Structure

```
Menu Bar Popover (primary interaction — widget-like, dense, glanceable)
├── Status: countdown timer + profile name (or "Ready to focus")
├── Profile cards: quick-start any pinned profile
├── Active block: extend / add site / view blocked attempts
├── ⌘K: command palette search
└── "Open Forge..." → full window

Full Window (NavigationSplitView — Liquid Glass sidebar)
├── Dashboard: profile cards, quick-start slider, today's stats, upcoming schedules
├── Profiles: list + editor (domains, apps, settings per profile)
├── Schedules: weekly schedule builder with profile assignment
├── Insights: Swift Charts — focus time, blocked attempts, streaks
└── Settings: notifications, sounds, iCloud sync, emergency recovery

Desktop Widget (WidgetKit — interactive)
├── Small: countdown timer + profile name
├── Medium: timer + blocked attempts + extend button
└── Large: timer + today's stats + quick-start buttons

Command Palette (⌘K — Raycast/Linear inspired)
└── Fuzzy search across all actions: start profiles, add domains, navigate, settings
```

### Key Screens

**Dashboard — No active block:**
- Greeting ("Good morning")
- Profile cards (pinned profiles with one-tap start)
- Quick block slider (ad-hoc duration without a profile)
- Today's summary (focus time, blocked attempts, streak)
- Upcoming scheduled blocks

**Dashboard — Active block:**
- Profile name and icon
- Large countdown timer
- Progress bar with percentage
- Blocked sites/apps count, end time
- Add Site and Extend buttons
- Live blocked attempt log (most-blocked sites)

**Profile Editor:**
- Name, icon (SF Symbol picker), color
- Mode toggle (blocklist/allowlist)
- Domain list with add/remove, import presets, validation
- App list with add from installed apps
- Per-profile options (subdomain expansion, local network, cache clearing)

**Schedule View:**
- Cards showing profile + weekdays + time range + enabled toggle
- Create/edit with weekday selector and time pickers

**Insights:**
- Swift Charts area chart for focus time over week/month
- Horizontal bar chart for most-blocked sites
- Streak calendar (github contribution-graph style)
- Week/month/year toggle

### Onboarding (progressive, 4 steps)

1. **Welcome:** Single screen explaining Forge's purpose and commitment model
2. **System Extension Approval:** Guided permission grant with explanation of why
3. **First Profile:** Interactive — "What distracts you most?" → select preset → customize
4. **First Block:** "Try a 15-minute block" — skippable for experienced users

Permissions requested in context (extension approval during onboarding, notification permission when first block ends).

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘K | Command palette |
| ⌘1-9 | Quick-start profile 1-9 |
| ⌘N | New profile |
| ⌘, | Settings |
| ⌘D | Edit current profile's domain list |
| ⌘I | Import blocklist |
| ⌘E | Export current profile |

### System Integration

| Integration | Purpose |
|-------------|---------|
| Shortcuts.app | "Start Work Mode" / "How much time left?" via App Intents |
| Desktop Widgets | Glanceable status, quick-start, stats (WidgetKit, interactive) |
| Focus Modes | Tie Forge profiles to macOS Focus modes |
| Notifications | Block start/end/expiring + optional blocked attempt alerts |
| Menu Bar | Always-present primary interface |
| Dock Badge | Optional countdown timer (preserved from v4) |

### Design System

| Element | Implementation |
|---------|---------------|
| Layout | NavigationSplitView (auto-glass sidebar on macOS 26) |
| Colors | System accent color + semantic colors (.primary, .secondary) |
| Icons | SF Symbols exclusively |
| Typography | System font with standard text styles |
| Cards | Rounded rectangles with .ultraThinMaterial background |
| Charts | Swift Charts framework |
| Animations | .spring() transitions, matchedGeometryEffect for state changes |
| Dark mode | Automatic via system colors and materials |
| Accessibility | VoiceOver labels, Dynamic Type, reduce motion support |

---

## 10. Testing Strategy

### Layer 1: Unit Tests (XCTest + Swift Testing)

| Component | What's tested | Approach |
|-----------|--------------|----------|
| BlockRuleset | Domain matching, wildcards, CIDR, ports | Pure logic, no mocks |
| BlockProfile / BlockSchedule | Model validation, schedule evaluation | In-memory SwiftData ModelContainer |
| SystemStateManifest | Encoding/decoding, integrity | Protocol-mocked file system |
| PF rule generation | Anchor file content, pf.conf modification | String output verification |
| iCloud sync encoding | Profile ↔ NSUbiquitousKeyValueStore | Mock KV store |
| Analytics aggregation | Session rollups, streaks, counts | In-memory SwiftData |
| Schedule evaluator | Time window matching, overnight spans, edge cases | Fixed dates |

### Layer 2: Integration Tests

| Test | What it validates |
|------|-------------------|
| App → Extension XPC | Ruleset delivery, bidirectional communication, reconnection |
| App → Helper XPC | Authorization, manifest write/read, PF installation |
| Extension ruleset persistence | Write → simulate reboot → verify reload |
| Cleanup timer | Install → advance past expiry → verify clean state |
| Full block lifecycle | Start → extend → expire → verify clean system |
| Profile ↔ iCloud sync | Write → read back via mock KV store |

### Layer 3: UI Tests (XCUITest)

| Flow | Steps |
|------|-------|
| Onboarding | Launch → extension approval → create profile → first block |
| Quick start | Menu bar → profile card → authenticate → block active |
| Profile CRUD | Create → edit → save → verify |
| Schedule CRUD | Create → set weekdays/times → toggle |
| Active block | Timer → add site → extend → verify end time |
| Command palette | ⌘K → type → select → verify action |
| Recovery | Settings → Emergency Recovery → confirm → system clean |

### Layer 4: System Tests (manual, real Mac required)

| Test | Verification |
|------|-------------|
| Reboot survival | Block → reboot → all three layers active |
| Extension disable | Block → disable in System Settings → PF still blocks |
| App uninstall | Delete app → PF + timer active → expiry → clean state |
| Sleep/wake | Block → sleep → wake → timer correct |
| OS update | Overwrite pf.conf → daemon re-adds anchor |

---

## 11. CI/CD & Distribution

### GitHub Actions Pipeline

**On pull request / push to main:**
1. Build all targets (app, extension, helper, CLI, widget)
2. Run SwiftLint
3. Run unit tests
4. Run UI tests

**On version tag (e.g., `v5.0.0`):**
1. Archive release build
2. Export with Developer ID signing
3. Notarize via `xcrun notarytool`
4. Staple notarization ticket
5. Create DMG
6. Generate Sparkle appcast
7. Upload to GitHub Releases

### Distribution

| Concern | Solution |
|---------|----------|
| Auto-updates | Sparkle 2 (Swift rewrite, EdDSA signatures) |
| Notarization | Automated via xcrun notarytool in CI |
| Code signing | Developer ID, secrets in GitHub Secrets |
| DMG creation | create-dmg tool |
| Appcast feed | Generated from git tags, hosted on GitHub Releases |
| Crash reporting | Sentry latest (opt-in) |

### Versioning

Semantic versioning: `MAJOR.MINOR.PATCH`. Build number from git commit count. Tags trigger release pipeline.

### Linting

SwiftLint with project-specific rules: 120-char line limit, 300-line type warning, 500-line file warning. Standard opt-in rules for closures, toggle_bool, first_where, etc.

---

## 12. Project Structure

```
Forge/
├── App/
│   ├── ForgeApp.swift            # @main, app lifecycle
│   ├── AppState.swift                  # @Observable global state
│   ├── MenuBarController.swift         # NSStatusItem + popover
│   └── CommandPalette.swift            # ⌘K handler
│
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── ActiveBlockView.swift
│   │   └── ProfileCardView.swift
│   ├── Profiles/
│   │   ├── ProfileListView.swift
│   │   ├── ProfileEditorView.swift
│   │   └── DomainListView.swift
│   ├── Schedules/
│   │   ├── ScheduleListView.swift
│   │   └── ScheduleEditorView.swift
│   ├── Insights/
│   │   ├── InsightsView.swift
│   │   ├── FocusTimeChart.swift
│   │   └── BlockedAttemptsChart.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   ├── Onboarding/
│   │   └── OnboardingFlow.swift
│   └── Shared/
│       ├── CountdownTimerView.swift
│       └── ProgressBarView.swift
│
├── Models/
│   ├── BlockProfile.swift
│   ├── BlockSchedule.swift
│   ├── BlockSession.swift
│   └── BlockRuleset.swift
│
├── Services/
│   ├── BlockEngine.swift               # Orchestrates start/stop/extend
│   ├── ScheduleEvaluator.swift         # Checks schedule triggers
│   ├── AnalyticsService.swift          # Aggregates session data
│   ├── XPCClient.swift                 # Talks to extension + helper
│   └── iCloudSyncService.swift         # NSUbiquitousKeyValueStore wrapper
│
├── ForgeFilterExtension/                  # System Extension target
│   ├── FilterExtension.swift           # NEFilterDataProvider
│   ├── DNSProxyExtension.swift         # NEDNSProxyProvider
│   ├── AppBlocker.swift                # EndpointSecurity client
│   ├── RulesetStore.swift              # Persist ruleset for reboot
│   ├── IPHostnameMap.swift             # DNS proxy → filter hostname map
│   └── Info.plist
│
├── ForgeHelper/                 # SMJobBless helper target
│   ├── HelperMain.swift                # XPC listener setup
│   ├── HelperDelegate.swift            # XPC connection handling
│   ├── HelperProtocol.swift            # ForgeHelperProtocol definition
│   ├── PFManager.swift                 # PF anchor operations
│   ├── ManifestManager.swift           # State manifest CRUD
│   ├── CleanupInstaller.swift          # LaunchDaemon timer install/remove
│   └── Info.plist + launchd plist
│
├── forge-cli/                    # CLI target
│   ├── CLI.swift                       # Swift ArgumentParser commands
│   └── RecoverCommand.swift            # forge-recovery logic
│
├── ForgeWidget/                  # WidgetKit target
│   ├── ForgeWidget.swift         # Widget bundle
│   ├── SmallWidgetView.swift
│   ├── MediumWidgetView.swift
│   └── TimelineProvider.swift
│
├── ForgeTests/                   # Unit tests
├── ForgeIntegrationTests/        # Integration tests
├── ForgeUITests/                 # UI tests
│
├── Resources/
│   ├── Localizable.xcstrings           # String catalog (13+ languages)
│   ├── Assets.xcassets                 # App icon, colors, images
│   └── PresetProfiles.json             # Built-in profile templates
│
├── Scripts/
│   ├── generate-appcast.sh             # Sparkle appcast generation
│   └── cleanup.sh                      # Bundled for helper to install
│
├── .github/
│   └── workflows/
│       └── ci.yml                      # Build + test + release pipeline
│
├── .swiftlint.yml
└── Forge.xcodeproj
```

---

## 13. Competitive Landscape

Research conducted across major competitors to inform feature decisions:

| App | Approach | Key Differentiator | Pricing |
|-----|----------|-------------------|---------|
| **Freedom** | Local proxy on port 7769 | Cross-device sync (Mac/Win/iOS/Android), focus sounds | $3.33/mo or ~$100 lifetime |
| **Cold Turkey** | OS-level blocking + browser extension | Strongest anti-bypass (5 lock types), one-time purchase | $39 one-time |
| **Focus** | macOS-native blocking | Scripting hooks at session start/end, Pomodoro timer | $19-99 one-time |
| **Opal** | Screen Time API (iOS) + native (Mac) | Heavy gamification (gems, leaderboards), 4M+ users | ~$100/year |
| **One Sec** | Friction/delay (breathing exercises) | Scientifically validated 57% usage reduction, broadest platform support | ~EUR 15/year |
| **Quittr** | Blocking + therapy | AI therapist, panic button, CBT-based recovery | ~$30-40/year |

### Forge Positioning

- **Strongest anti-bypass:** Three independent enforcement layers (Freedom uses one, Cold Turkey uses two)
- **Open source:** Only open-source option in the category
- **Privacy-first:** All data local (Freedom/Opal are cloud-based)
- **DoH-aware:** Network Extension catches encrypted DNS bypass (Freedom's proxy doesn't)
- **App blocking:** Kernel-level via EndpointSecurity (Cold Turkey and Focus also do this)
- **No subscription required:** Architecture supports free/freemium/one-time (TBD)

---

## 14. Migration from v4

### Data Migration

On first launch of v5, detect existing v4 installation:

1. Read v4 `NSUserDefaults` for `org.eyebeam.SelfControl`
2. Import `Blocklist` array → create a "Migrated" profile
3. Import `BlockAsWhitelist` setting → set profile mode
4. Import preferences (TimerWindowFloats, BadgeApplicationIcon, etc.) → map to v5 settings
5. Import v4 secured settings from `/usr/local/etc/` plist if present

### Active Block Migration

If v4 has an active block when v5 is first launched:
1. Detect via `SCBlockUtilities.anyBlockIsRunning` check (read PF rules + hosts file)
2. Show migration dialog: "Forge detected an active block from the previous version. It will expire at [time]. Once it expires, v5 will take over."
3. Do NOT interfere with the active v4 block — let it expire naturally
4. After expiry, v5 activates normally

### Cleanup

After successful migration:
- Remove v4 daemon (`org.eyebeam.selfcontrold`) via SMJobRemove
- Remove v4 helper from `/Library/PrivilegedHelperTools/`
- Clean up legacy settings files
- Remove v4 PF anchor (`org.eyebeam`) and hosts file entries if no active block

---

## 15. Risks & Open Questions

### Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Apple denies Network Extension entitlement | Cannot ship network filtering | Apply early with clear justification; predecessor SelfControl has a 15+ year track record as a legitimate content filter |
| Apple denies EndpointSecurity entitlement | Cannot do kernel-level app blocking | Fallback to NSWorkspace observe+kill pattern (reactive but functional) |
| NEFilterDataProvider performance impact | System-wide network slowdown | Respond quickly, cache decisions, minimize flow inspection |
| Chrome/Brave remoteHostname is nil | Can't identify blocked sites by hostname | IP→hostname map from DNS proxy + TLS SNI inspection fallback |
| macOS updates break PF rules | Anchor reference removed from pf.conf | Cleanup daemon re-adds on next 30s poll |
| SMJobBless deprecated in future | Helper installation mechanism breaks | Monitor SMAppService sandboxing requirements; migrate when feasible |

### Product Open Questions

| Question | Options | Decision |
|----------|---------|----------|
| Monetization model | Free / freemium / one-time purchase | Deferred — architecture supports all |
| Friction/mindfulness mode | Hard block only vs optional gentle delay | Deferred — architecture extensible |
| Content-based blocking | Domain-only vs page content inspection | Domain-only in v1; browser extension for content in future |
| Mac App Store | Direct-only vs also App Store | Direct-only in v1; NE approach is App Store compatible |

### Entitlement Applications Required

Both must be submitted to Apple before development can be fully tested:

1. **Network Extension entitlement** — for NEFilterDataProvider + NEDNSProxyProvider
2. **EndpointSecurity entitlement** — for app blocking via AUTH_EXEC

Apply for development entitlements immediately. Distribution entitlements needed before shipping.

---

## 16. Appendices

### A. Entitlements Required

```xml
<!-- Forge.app -->
com.apple.developer.networking.networkextension  (content-filter-provider, dns-proxy)
com.apple.developer.ubiquity-kvstore-identifier
com.apple.security.application-groups

<!-- ForgeFilterExtension.systemextension -->
com.apple.developer.networking.networkextension  (content-filter-provider, dns-proxy)
com.apple.developer.endpoint-security.client
com.apple.security.application-groups
com.apple.security.app-sandbox  (required for system extensions)

<!-- ForgeHelper -->
(no entitlements — runs unsandboxed via SMJobBless)

<!-- forge-cli -->
com.apple.security.application-groups
```

### B. Known DoH Server IPs to Block

The content filter must block connections to these IPs to prevent DNS-over-HTTPS bypass:

```
# Google
8.8.8.8, 8.8.4.4, 2001:4860:4860::8888, 2001:4860:4860::8844

# Cloudflare
1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001

# Quad9
9.9.9.9, 149.112.112.112, 2620:fe::fe, 2620:fe::9

# OpenDNS
208.67.222.222, 208.67.220.220

# NextDNS
45.90.28.0/24, 45.90.30.0/24

# AdGuard
94.140.14.14, 94.140.15.15
```

This list must be maintained as new DoH providers emerge. It should be a configuration file, not hardcoded.

### C. Built-in Profile Presets

```json
[
  {
    "name": "Social Media",
    "icon": "bubble.left.and.bubble.right.fill",
    "color": "#3B82F6",
    "mode": "blocklist",
    "domains": [
      "facebook.com", "*.facebook.com", "instagram.com", "*.instagram.com",
      "twitter.com", "*.twitter.com", "x.com", "*.x.com",
      "reddit.com", "*.reddit.com", "tiktok.com", "*.tiktok.com",
      "snapchat.com", "*.snapchat.com", "pinterest.com", "*.pinterest.com",
      "linkedin.com", "*.linkedin.com", "tumblr.com", "*.tumblr.com",
      "threads.net", "*.threads.net", "bsky.app", "*.bsky.app",
      "mastodon.social", "*.mastodon.social"
    ],
    "appBundleIDs": [
      "com.facebook.Facebook", "com.burbn.instagram",
      "com.atebits.Tweetie2", "com.reddit.Reddit"
    ]
  },
  {
    "name": "News & Media",
    "icon": "newspaper.fill",
    "color": "#F59E0B",
    "mode": "blocklist",
    "domains": [
      "news.ycombinator.com", "cnn.com", "*.cnn.com",
      "nytimes.com", "*.nytimes.com", "bbc.com", "*.bbc.com",
      "youtube.com", "*.youtube.com", "netflix.com", "*.netflix.com",
      "twitch.tv", "*.twitch.tv", "digg.com", "buzzfeed.com"
    ],
    "appBundleIDs": []
  },
  {
    "name": "Gaming",
    "icon": "gamecontroller.fill",
    "color": "#8B5CF6",
    "mode": "blocklist",
    "domains": [
      "store.steampowered.com", "*.steampowered.com",
      "discord.com", "*.discord.com", "twitch.tv", "*.twitch.tv",
      "epicgames.com", "*.epicgames.com", "roblox.com", "*.roblox.com"
    ],
    "appBundleIDs": [
      "com.valvesoftware.steam", "com.hnc.Discord",
      "com.epicgames.EpicGamesLauncher"
    ]
  }
]
```

### D. References

- [NEFilterDataProvider — Apple Developer Documentation](https://developer.apple.com/documentation/networkextension/nefilterdataprovider)
- [NEDNSProxyProvider — Apple Developer Documentation](https://developer.apple.com/documentation/networkextension/nednsproxyprovider)
- [EndpointSecurity — Apple Developer Documentation](https://developer.apple.com/documentation/endpointsecurity)
- [SMJobBless — Apple Developer Documentation](https://developer.apple.com/documentation/servicemanagement/smjobbless)
- [NSUbiquitousKeyValueStore — Apple Developer Documentation](https://developer.apple.com/documentation/foundation/nsubiquitouskeyvaluestore)
- [Network Extensions for the Modern Mac — WWDC 2019](https://developer.apple.com/videos/play/wwdc2019/714/)
- [Build an Endpoint Security App — WWDC 2020](https://developer.apple.com/videos/play/wwdc2020/10159/)
- [What's New in Endpoint Security — WWDC 2022](https://developer.apple.com/videos/play/wwdc2022/110345/)
- [Filter and Tunnel Network Traffic — WWDC 2025](https://developer.apple.com/videos/play/wwdc2025/234/)
- [Apple Human Interface Guidelines — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- [Liquid Glass Design Language — WWDC 2025](https://developer.apple.com/design/)
