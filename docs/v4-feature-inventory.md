# SelfControl v4 — Complete Feature Inventory

**Date:** 2026-03-27
**Purpose:** Exhaustive catalog of every feature, behavior, and capability in the current SelfControl v4.0.2 codebase. Used as the baseline for the v5 rewrite to ensure no features are lost.

---

## 1. Blocking Engine

### Dual Blocking System

**Host File Blocking (HostFileBlocker.m)**
- Modifies `/etc/hosts` to redirect blocked domains to `0.0.0.0` (IPv4) and `::` (IPv6)
- Creates backup at `/etc/hosts.bak` before modification
- Supports VPN host files: `/etc/pulse-hosts.bak`, `/etc/jnpr-pulse-hosts.bak`, `/etc/hosts.ac`
- Block entries wrapped in markers: `# BEGIN SELFCONTROL BLOCK` / `# END SELFCONTROL BLOCK`
- Thread-safe via NSLock
- Supports append mode (add domains to running block)

**Packet Filter Blocking (PacketFilter.m)**
- Uses BSD packet filter via `/sbin/pfctl`
- Rules written to `/etc/pf.anchors/org.eyebeam`
- Anchor reference appended to `/etc/pf.conf`
- PF token stored at `/etc/SelfControlPFToken`
- Two rule modes:
  - Blocklist: `block return out` rules deny specific IPs/domains
  - Allowlist: `block return out` all TCP/UDP, then `pass out` for allowed IPs
- Default allow policies: DNS (53), NTP (123), DHCP (67-68), mDNS (5353)
- Supports CIDR notation for IP ranges
- Supports port-specific blocking

### Block Entry Parsing (SCBlockEntry.m)
- Format: `hostname[/maskLen][:port]`
- Examples: `example.com`, `192.168.1.0/24`, `example.com:8080`
- Validates IP addresses, hostnames (RFC-compliant)
- Prevents blocking bare `*` without port (safety measure)

### Domain Resolution
- `ipAddressesForDomainName:` uses CFHost for synchronous DNS resolution
- Operation queue with 35 concurrent operations for parallel resolution
- Warns if resolution takes >2.5 seconds
- Supports IPv4 and IPv6

### Special Domain Handling
- **Google/YouTube/Picasa/Blogger/Sketchup**: Regex detection, hardcoded Google IP ranges (~60 CIDR blocks, last updated 2021)
- **Facebook**: Special IP ranges from AS32934
- **Twitter/Netflix**: Additional CDN domains
- **www variants**: Automatically blocks both with and without `www.` prefix

### Allowlist Scraper (AllowlistScraper.m)
- Discovers linked domains on allowlisted sites via `NSDataDetector`
- HTTP request with 5-second timeout
- Excludes known distraction sites from auto-add: Instagram, Twitter, Facebook, Reddit, YouTube, Pinterest, LinkedIn, Tumblr
- Only active when `includeLinkedDomains` is enabled

---

## 2. Daemon (org.eyebeam.selfcontrold)

### Lifecycle
- Service name: `org.eyebeam.selfcontrold`
- Singleton pattern: `SCDaemon.sharedDaemon`
- Runs as root via SMJobBless (launchd system daemon)
- 120-second inactivity timeout — auto-unloads when not needed
- Inactivity check every 15 seconds

### Block Operations
- **Start block**: Validates parameters, stores settings, installs rules, starts checkup timer
- **Extend block**: Only extends (never shortens), max 24-hour extension per call
- **Update blocklist**: Adds new domains to running block (blocklist mode only, append mode)
- **Integrity check**: Every 15 seconds, verifies PF and hosts rules exist, re-applies if missing
- **Checkup timer**: Every 1 second, checks for expiration/tampering

### XPC Security
- Validates connecting clients via SecCode API
- Requires: bundle ID `org.eyebeam.SelfControl` or `org.eyebeam.selfcontrol-cli`
- Version >= 407, valid Apple code signing, specific certificate fields
- Two authorization rights:
  - `org.eyebeam.SelfControl.startBlock` — requires admin, 2-minute timeout
  - `org.eyebeam.SelfControl.modifyBlock` — requires admin, 2-minute timeout
- Touch ID/biometric auth supported (macOS 10.12.2+)

### Hosts File Watching
- `SCFileWatcher` monitors `/etc/hosts` for changes
- Triggers integrity check on modification (tampering detection)

---

## 3. Settings System (SCSettings.m)

### Storage
- Path: `/usr/local/etc/.{SHA1_hash}.plist` (hash includes serial number)
- Format: binary plist, permissions 0755, owner root:wheel
- Read by app/CLI (read-only mode), written by daemon only (root)

### Core Settings Keys
| Key | Type | Default |
|-----|------|---------|
| BlockEndDate | NSDate | distantPast |
| ActiveBlocklist | NSArray | [] |
| ActiveBlockAsWhitelist | BOOL | NO |
| BlockIsRunning | BOOL | NO |
| TamperingDetected | BOOL | NO |
| EvaluateCommonSubdomains | BOOL | YES |
| IncludeLinkedDomains | BOOL | YES |
| BlockSoundShouldPlay | BOOL | NO |
| BlockSound | NSNumber | 5 |
| ClearCaches | BOOL | YES |
| AllowLocalNetworks | BOOL | YES |
| EnableErrorReporting | BOOL | system-dependent |
| SettingsVersionNumber | NSNumber | 0 |
| LastSettingsUpdate | NSDate | distantPast |

### Synchronization
- Distributed notifications: `org.eyebeam.SelfControl.SCSettingsValueChanged`
- Auto-sync timer: 30 seconds with 30-second leeway
- Version number conflict resolution (newer wins, timestamp tiebreak)

---

## 4. User Interface

### Main Control Window
- Duration slider: 1 minute to MaxBlockLength (default 1440 = 24 hours)
- "Start Block" button (disabled when blocklist empty or duration is 0)
- "Edit Blocklist/Allowlist" button (dynamically labeled)
- Blocklist teaser label (first 60 chars)
- Loading state: "Starting Block..." during initialization

### Timer Window (HUD-style)
- Large countdown: HH:MM:SS format, 42pt font
- "Add to Blocklist" button — opens sheet for domain input during active block
- "Extend Block Timer" button — opens sheet with duration slider
- "View Blocklist" button
- "Stuck? Stop block manually" — appears after 7+ failed timer clears (red, bold)
- Legacy block warning label
- Shows "Finishing" when timer reaches 0
- Dock badge: HH:MM format (if BadgeApplicationIcon enabled)

### Domain List Window
- Editable table: domain names with add/remove
- Radio matrix: Blocklist vs Allowlist mode toggle
- Import menu:
  - Common Distracting Sites (built-in)
  - News & Publications (built-in)
  - From Mail (incoming/outgoing servers)
  - From MailMate (incoming/outgoing servers)
  - From Thunderbird (incoming/outgoing servers)
- Validation: highlights invalid entries in red (when HighlightInvalidHosts enabled)
- Read-only during active block
- Supports paste of newline-separated domain lists

### Preferences Window (MASPreferencesWindowController)

**General Preferences:**
- Show countdown in Dock (BadgeApplicationIcon)
- Timer window float on top (TimerWindowFloats)
- Play sound on completion (BlockSoundShouldPlay + sound dropdown)
- Send anonymized error reports (EnableErrorReporting)
- Auto check for updates (Sparkle)

**Advanced Preferences:**
- Clear browser cache (ClearCaches)
- Block common subdomains (EvaluateCommonSubdomains)
- Highlight invalid hosts (HighlightInvalidHosts)
- Allow local networks (AllowLocalNetworks)
- Verify internet connection (VerifyInternetConnection)
- Include linked sites for allowlist (IncludeLinkedDomains)

### "Get Started" Window
- First-launch informational window (FirstTime.xib)
- Shows once (GetStartedShown flag)
- Reopenable via Help menu

### Alerts & Dialogs
- Long block warning (>= 2 days or >= 8 hours for first block) — suppressible
- Allowlist confirmation — suppressible
- Network connection required (when VerifyInternetConnection enabled)
- Block start errors (various codes 100-104)
- Manual block kill success/failure

---

## 5. Menu Structure & Keyboard Shortcuts

### Menus
- SelfControl: About, Check Updates, Preferences (⌘,), Edit Blocklist (⌘D), Quit (⌘Q)
- File: Close (⌘W), Open Blocklist (⌘O), Save Blocklist (⌘S)
- Edit: Undo (⌘Z), Redo (⇧⌘Z), Cut/Copy/Paste/Delete/Select All, Speech
- Window: Minimize (⌘M), Zoom
- Help: Get Started, Support Hub, FAQ (⌘?)

---

## 6. Import/Export

- Save blocklist: binary plist (.selfcontrol), contains blocklist array + allowlist boolean
- Open blocklist: reads .selfcontrol file, replaces current list
- Drag-and-drop .selfcontrol files onto app icon

---

## 7. CLI Tool (selfcontrol-cli)

### Commands
- `start` — Start a block (`--blocklist <path>`, `--enddate <ISO8601>`, `--settings <JSON>`, `--uid <uid>`)
- `is-running` — Check if block active
- `print-settings` — Dump all settings
- `version` — Show version
- `remove` — Exits with "Nice try" error

### Legacy support
- Accepts positional arguments: `selfcontrol-cli <uid> <path> <enddate>`

---

## 8. Killer Helper (SCKillerHelper)

### Purpose
Emergency block removal tool (runs as root)

### Security
- Requires killer key (time-based, 10-second validity window)
- Validates date and key before execution

### Actions
1. Logs debug info to ~/Documents/SelfControl-Killer.log
2. Unloads legacy launchd job (v1-3)
3. Removes modern daemon (v4) via SMJobRemove
4. Force-clears blocks (both PF and hosts)
5. Resets all settings to defaults
6. Removes PF token, anchor, and lock files

### Trigger
- Timer window "Stuck?" button (after 7+ failed clears)
- Standalone SelfControl Killer.app

---

## 9. System Behaviors

### Reboot
- Block persists (PF rules in pf.conf, hosts file modified)
- Daemon auto-loads via launchd
- Checkup restores any missing rules

### Sleep/Wake
- Block persists, checkup continues, rules immediately active on wake

### User Switching
- Different users can have different blocks (UID-based settings)
- Daemon is system-wide (single instance)

### Time Changes
- Clock backward: recomputes BlockEndDate (prevents permablocks)
- Clock forward: block may appear expired (triggers removal)

### Tampering Detection
- If hosts file modified during block: cheater-background.png applied to all desktops
- TamperingDetected flag in settings

### Browser Cache Clearing
- Chrome/Chromium, Safari, Firefox, Opera caches cleared
- DNS cache flushed via `dscacheutil -flushcache`

---

## 10. Localization

13 languages: Danish, German, English, Spanish, Persian, French, Italian, Japanese, Korean, Dutch, Portuguese (Brazil), Swedish, Turkish, Chinese (Simplified)

---

## 11. Auto-Updates

Sparkle framework with DSA + edDSA signatures, HTTPS update feed, system profiling enabled.

---

## 12. Error Reporting

Sentry integration (opt-in), separate project IDs per target, breadcrumbs for all major operations.

---

## 13. User Defaults (NSUserDefaults)

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| Blocklist | Array | [] | Domains to block |
| BlockAsWhitelist | BOOL | NO | Allowlist mode |
| BlockDuration | Integer | 1 | Minutes |
| MaxBlockLength | Integer | 1440 | Max duration (minutes) |
| TimerWindowFloats | BOOL | NO | Timer floats above windows |
| BadgeApplicationIcon | BOOL | YES | Dock countdown |
| BlockSoundShouldPlay | BOOL | NO | Sound on completion |
| BlockSound | Integer | 5 | System sound index |
| ClearCaches | BOOL | YES | Clear browser caches |
| EvaluateCommonSubdomains | BOOL | YES | Block www.* variants |
| HighlightInvalidHosts | BOOL | YES | Red highlight invalid domains |
| AllowLocalNetworks | BOOL | YES | Exempt local addresses |
| VerifyInternetConnection | BOOL | YES | Require network |
| IncludeLinkedDomains | BOOL | YES | Auto-discover linked domains |
| EnableErrorReporting | BOOL | system | Sentry opt-in |
| WhitelistAlertSuppress | BOOL | NO | Suppress allowlist warning |
| SuppressLongBlockWarning | BOOL | NO | Suppress long block warning |
| GetStartedShown | BOOL | NO | First-run shown |
| FirstBlockStarted | BOOL | NO | Ever started a block |
| V4MigrationComplete | BOOL | NO | Migrated from v3 |

---

## 14. Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| MASPreferences | 1.1.4 | Preferences window controller |
| TransformerKit | 1.1.1 | Value transformers |
| FormatterKit | 1.8.0 | Time interval formatting |
| LetsMove | 1.24 | Move-to-Applications prompt |
| Sentry | 7.3.0 | Crash reporting |
| Sparkle | (embedded) | Auto-updates |
| ArgumentParser | (submodule) | CLI argument parsing |
