# SelfControl — Critical Architectural Review

**Date:** 2026-03-26
**Reviewer:** Senior macOS Software Architect
**Project:** SelfControl (macOS website blocker)
**Version Reviewed:** 4.0.2 (Build 410)

---

## What the Project Does Well

- **XPC architecture** for privilege elevation is the correct macOS pattern (SMJobBless + privileged daemon)
- **Multiple enforcement mechanisms** (hosts file + packet filter) provide defense in depth
- **Sentry integration** for crash reporting in production
- **Localization** across 13 languages — impressive for an open-source tool
- **Touch ID support** recently added for auth prompts
- **Hardened runtime** enabled in build settings
- **Sparkle** for auto-updates over HTTPS

---

## Critical Issues

### 1. Deployment Target: macOS 10.10 (2014)

This is the single biggest technical debt. Yosemite hasn't received security patches in ~8 years. It blocks adoption of modern APIs (Network.framework, Endpoint Security, UserNotifications, SwiftUI). Raise to at least macOS 12 (Monterey) — that's the oldest version with meaningful user share today.

### 2. NSAllowsArbitraryLoads = true (daemon + CLI)

Both the daemon and CLI Info.plists disable App Transport Security entirely. For an app that manipulates network traffic, this is a serious credibility gap. ATS should be enforced with specific exceptions only where needed.

### 3. No App Sandbox

The main app has no sandbox entitlements. While the daemon legitimately needs root, the GUI app itself should be sandboxed with only the entitlements it needs (XPC, network client, file read access for blocklists).

### 4. No Notarization Pipeline

Modern macOS Gatekeeper requires notarization. The `distribution-build.rb` script handles Sparkle signing but has no `xcrun notarytool` step. Users on macOS 10.15+ will get scary warnings or outright refusal to launch.

### 5. Hardcoded Google IP Ranges (Last Updated 2021)

`BlockManager.m` has ~60 lines of hardcoded Google IP ranges for allowlist mode, with `8.8.4.0/24` duplicated 5 times. These are 4+ years stale. Google's IP infrastructure changes regularly — this approach is fundamentally broken for long-term maintenance.

### 6. /etc/hosts Modifications Are Not Atomic

`HostFileBlocker.m` reads, modifies, then writes `/etc/hosts` in separate operations. Another process (or the user, or a VPN client) can modify the file between read and write, causing data loss. The restore path is worse: it deletes the hosts file *then* moves the backup — if the move fails, the hosts file is gone.

### 7. PF Token Stored Unencrypted

`PacketFilter.m` writes a plain-text token to `/etc/SelfControlPFToken`. If deleted externally, block removal becomes impossible. No integrity protection.

### 8. Thread Safety Issues Throughout

- `appendMode` in `BlockManager.m` is a module-level BOOL with no synchronization
- `refreshUserInterface()` uses both a manual NSLock and `dispatch_sync` — redundant and deadlock-prone
- `[NSThread detachNewThreadSelector:@selector(installBlock)]` creates unmanaged threads accessing shared state
- XPC connection invalidation handler has a potential deadlock via `dispatch_sync(main_queue)` from main thread

### 9. Test Coverage < 5%

One test file (`SCUtilityTests.m`) covers only utility functions. Zero tests for:
- Block activation/deactivation
- Daemon XPC communication
- Hosts file manipulation
- Packet filter rules
- Settings synchronization
- UI controllers

### 10. No CI/CD

No GitHub Actions, no automated builds, no automated testing. Releases are manual via a Ruby script that requires a mounted secrets volume.

---

## Technical Debt Summary

| Severity | Issue | Location |
|----------|-------|----------|
| **CRITICAL** | macOS 10.10 deployment target | project.pbxproj, Podfile |
| **CRITICAL** | ATS disabled in daemon/CLI | selfcontrold-Info.plist |
| **CRITICAL** | Non-atomic /etc/hosts writes | HostFileBlocker.m |
| **CRITICAL** | No notarization | distribution-build.rb |
| **HIGH** | Hardcoded stale Google IPs | BlockManager.m:299-357 |
| **HIGH** | Thread safety across codebase | Multiple files |
| **HIGH** | No XPC rate limiting | SCXPCAuthorization.m |
| **HIGH** | Daemon self-destructs during active block | SCDaemon.m:109-126 |
| **MEDIUM** | All CocoaPods outdated (Sentry 7.3 vs 8.x) | Podfile |
| **MEDIUM** | Deprecated SMJobRemove API | SCKillerHelper/main.m |
| **MEDIUM** | PF token unencrypted | PacketFilter.m |
| **MEDIUM** | DNS resolution blocks with no timeout | BlockManager.m |
| **LOW** | <5% test coverage | SelfControlTests/ |
| **LOW** | No CI/CD pipeline | (missing) |

---

## Detailed Component Analysis

### Daemon Architecture (Daemon/)

**Files:** SCDaemon.m/h, DaemonMain.m, SCDaemonXPC.m/h, SCDaemonBlockMethods.m/h, SCDaemonProtocol.h

**Thread Safety Concerns:**
- `appendMode` variable in BlockManager.m is a module-level BOOL with no synchronization
- Multiple threads access shared state without proper locking outside of daemon method lock
- NSTimer-based checkup system doesn't have thread-safe teardown guarantees

**Error Handling:**
- Inconsistent: some XPC methods use reply callbacks, others rely on Sentry logging
- No timeout handling for synchronous operations like `syncSettingsAndWait:` — just arbitrary 5-second waits
- Network/DNS resolution errors in BlockManager.m aren't properly bubbled up to callers

**Memory Management:**
- File handles in PacketFilter.m aren't always closed on error paths
- `enterAppendMode()` returns without closing handle if file doesn't exist
- `NSFileHandle fileHandleForWritingAtPath:` can return nil but isn't always checked

**Daemon Lifecycle:**
- 2-minute inactivity timeout is hardcoded (SCDaemon.m line 15)
- Timer fires every 15 seconds regardless of block status — unnecessary wakeups
- Daemon unloads itself on inactivity even if block is running
- No graceful shutdown mechanism — just calls `exit()`

### Block Management (Block Management/)

**Files:** BlockManager.m/h, HostFileBlocker.m/h, HostFileBlockerSet.m/h, PacketFilter.m/h, SCBlockEntry.m/h

**Packet Filter Issues:**
- Hardcoded Google IP ranges with duplicates (`8.8.4.0/24` appears 5 times)
- Direct writes to `/etc/pf.conf` and `/etc/pf.anchors/org.eyebeam` with no atomic operations
- If pfctl command fails, inconsistent state persists
- No verification that rules actually loaded after writing

**Hosts File Race Conditions:**
- Lock only protects individual operations, not multi-step sequences
- `revertFileContentsToDisk()` + `writeNewFileContents()` aren't atomic
- `restoreBackupHostsFile()` does removeItem then moveItem — if moveItem fails, hosts file is deleted

**DNS Resolution:**
- `ipAddressesForDomainName:` uses CFHost which blocks — called from NSBlockOperation queue
- 2.5-second threshold warning but no timeout enforcement
- Returns empty array on failure silently

**Allowlist Mode:**
- Google IP ranges hardcoded for allowlist — error-prone and stale
- No documentation why allowlist is fundamentally limited

### XPC Communication (Common/)

**Files:** SCXPCClient.m/h, SCXPCAuthorization.m/h, SCDaemonProtocol.h

**Security Issues:**
- Requirement string includes machine-specific team ID `EG6ZYP3AQH`
- Minimum version check `CFBundleVersion >= 407` is hardcoded
- No rate limiting on authorization attempts — malicious app could DoS with repeated requests
- auditToken used only for code signing check, not for ongoing request validation

**Connection Management:**
- Invalidation handler has potential deadlock via `dispatch_sync(dispatch_get_main_queue())` from main thread
- No exponential backoff for retries after daemon crash

### Settings Management (Common/SCSettings.m/h)

**Synchronization Problems:**
- Settings file path includes SHA1 of serial number — if computed differently across systems, different settings files
- 30-second sync interval with 30-second leeway means settings could be 60 seconds out of sync
- `syncSettingsAndWait:` waits on semaphore but doesn't verify write completed to disk

**Version Number Conflict Resolution:**
- No UUID/hostname to identify source of conflict
- If two daemon instances run simultaneously, version number collisions likely
- Distributed notification relay has potential for infinite loop if description format changes

### CLI Tool (cli-main.m)

- Legacy positional argument support with argv array access without bounds checking
- Blocklist file read with no validation of file permissions
- Inconsistent exit codes (mixes EX_SOFTWARE, EX_CONFIG, EX_IOERR)

### Killer Helper (SCKillerHelper/)

- killerKey validation uses time-based string comparison with 10-second window — no cryptographic signature
- Runs as root and accepts controlling UID argument — no validation UID exists as system user
- Log written to ~/Documents/SelfControl-Killer.log — potential privacy leak

### Dependencies

- **All CocoaPods significantly outdated:**
  - MASPreferences 1.1.4 — legacy/unmaintained
  - TransformerKit 1.1.1 — legacy/unmaintained
  - FormatterKit 1.8.0 — legacy/unmaintained
  - LetsMove 1.24 — legacy/unmaintained
  - Sentry 7.3.0 — current is 8.x with better macOS support
- Podfile.lock not committed — reproducibility issue
- Sparkle framework embedded as binary — version unclear

### Build Configuration

- GCC model tuning references G5 (PowerPC era — obsolete)
- Swift bridging header configured but no Swift code in project
- No GitHub Actions or any CI/CD pipeline
- distribution-build.rb requires mounted secrets volume — not CI-compatible

---

## If Building From Scratch for Modern macOS

### 1. Use Swift + Network Extension Framework

The biggest architectural change. Apple's **Network Extension** framework (`NEFilterDataProvider`, `NEDNSProxyProvider`) is the modern, supported way to filter network traffic on macOS. It:
- Doesn't require root or a privileged daemon
- Survives reboots natively via system extension
- Works with encrypted DNS (DoH/DoT) — the current hosts-file approach is trivially bypassed by any browser using DoH
- Is App Store compatible
- Gets proper sandboxing and entitlements

This eliminates the entire daemon + helper + hosts file + packet filter architecture.

### 2. System Extension Instead of SMJobBless

Replace the privileged helper/daemon with a **System Extension** (`EndpointSecurity` or `NetworkExtension`). System Extensions:
- Are user-approved via System Preferences
- Run in userspace (not as root)
- Survive app deletion (persist until explicitly removed)
- Are the Apple-recommended replacement for kexts and privileged helpers

### 3. SwiftUI + Combine for the UI

The current UI is XIB-based with manual outlet wiring. A modern rewrite would use:
- **SwiftUI** for all UI (preferences, timer window, blocklist editor)
- **Combine** for reactive settings sync (replacing NSDistributedNotificationCenter + polling)
- **UserNotifications** framework instead of the custom notification approach

### 4. Structured Concurrency (async/await)

Replace all the manual threading (`NSThread`, `NSOperationQueue`, `dispatch_sync`, `NSLock`) with Swift structured concurrency:
- `async/await` for XPC calls
- `Actor` isolation for settings (eliminates all synchronization bugs)
- `TaskGroup` for parallel DNS resolution with proper cancellation and timeouts

### 5. CloudKit or iCloud Key-Value Store for Settings Sync

Instead of plist files in `/usr/local/etc/` with distributed notifications, use:
- `NSUbiquitousKeyValueStore` for cross-device blocklist sync
- `UserDefaults` with app groups for local daemon-app communication
- No more manual file watching or version-number conflict resolution

### 6. DNS-over-HTTPS Awareness

The current approach (modifying `/etc/hosts`) is **completely ineffective** against browsers with DoH enabled (Firefox, Chrome, Safari in some configs). A Network Extension-based approach can intercept at the socket level regardless of DNS resolution method.

### 7. Proper Test Architecture

- Unit tests for all blocking logic (mock the system interfaces)
- Integration tests for XPC communication
- UI tests for critical flows (start block, extend block, add sites)
- Snapshot tests for UI
- CI with GitHub Actions running `xcodebuild test` on every PR

### 8. Modern Distribution

- **Mac App Store** distribution (possible with Network Extension approach)
- Or: GitHub Actions CI → build → notarize → Sparkle update feed
- No manual secrets volume needed — use GitHub Secrets + `notarytool`

### 9. Alternative Approaches to the Core Problem

| Approach | Pros | Cons |
|----------|------|------|
| **Network Extension (filter)** | Apple-supported, encrypted DNS aware, sandboxed | Requires user approval in System Preferences |
| **DNS proxy (NEDNSProxyProvider)** | Intercepts all DNS, lightweight | Doesn't block by IP, only domain |
| **Content Filter (NEFilterDataProvider)** | Deep packet inspection possible | Heavy, requires entitlement from Apple |
| **Firewall profile (MDM-style)** | Survives all user bypass attempts | Requires MDM enrollment, not practical for individuals |
| **Browser extension + system companion** | Works inside encrypted connections | Per-browser, user can disable |

The strongest approach for a from-scratch rewrite: **NEDNSProxyProvider + NEFilterDataProvider** combo. The DNS proxy handles domain blocking, and the content filter handles IP-based rules as fallback.

---

## Recommended Modernization Path (If Incremental)

If a full rewrite isn't feasible, prioritize these changes in order:

1. **Raise deployment target to macOS 12** — unlocks modern APIs
2. **Add notarization to the build** — immediate user-facing fix
3. **Fix ATS / remove NSAllowsArbitraryLoads** — security credibility
4. **Make /etc/hosts writes atomic** (write to temp, `rename()`) — data safety
5. **Replace hardcoded Google IPs** with a dynamic fetch or remove the feature
6. **Add GitHub Actions CI** — build + test on every PR
7. **Update all CocoaPods** — especially Sentry to 8.x
8. **Add tests for BlockManager and HostFileBlocker** — highest-risk code
9. **Begin Network Extension migration** as a parallel effort
