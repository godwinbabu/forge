# Forge

> *Forge your focus. Block distractions. No compromises.*

Forge is a modern macOS focus app that blocks distracting websites and apps with an unbypassable commitment mechanism. Built in Swift/SwiftUI for macOS 15+.

## Features

- **Website blocking** — DNS interception + content filtering via Network Extension, with DNS-over-HTTPS bypass protection
- **App blocking** — kernel-level launch denial via EndpointSecurity, with NSWorkspace fallback
- **Commitment mechanism** — three-stage bypass friction: re-enable prompt → typing challenge → 10-minute cooldown
- **Profiles** — named blocking configurations with domain lists, app lists, and per-profile options
- **Recurring schedules** — blocks start automatically on a weekly cadence with overnight span support
- **Usage insights** — focus time trends, blocked attempt counts, streak tracking via Swift Charts
- **Command palette** — ⌘K fuzzy search across all actions
- **Desktop widgets** — live countdown timer and blocked attempt count
- **Cross-device sync** — profiles sync via iCloud (NSUbiquitousKeyValueStore)
- **Shortcuts integration** — query block status via Siri and Shortcuts.app
- **Notifications** — block start, ending soon (5 min), and block ended alerts
- **Menu bar-first** — primary interaction via menu bar popover
- **Privacy-first** — all data local, optional iCloud sync, optional crash reporting
- **Auto-updates** — Sparkle 2 with EdDSA-signed appcast

## Architecture

```
Forge.app (SwiftUI, menu bar + window)
├── ForgeKit (shared framework — models, matching, protocols)
├── ForgeFilterExtension.systemextension
│     ├── NEFilterDataProvider (network traffic filtering)
│     ├── NEDNSProxyProvider (DNS interception)
│     └── EndpointSecurity (app launch blocking)
├── forge-cli (status queries + emergency recovery)
└── ForgeWidget (WidgetKit — countdown + stats)
```

## Building

```bash
# Generate Xcode project
brew install xcodegen
xcodegen generate

# Build
xcodebuild -scheme Forge -destination 'platform=macOS' build

# Run tests
xcodebuild test -scheme ForgeKit -destination 'platform=macOS'
```

## Requirements

- macOS 15 (Sequoia) or later
- Xcode 16+
- Apple Developer Program membership (Network Extension + EndpointSecurity entitlements)

## CLI

```bash
# Check block status
forge status

# Emergency recovery (clears all block state)
forge recover --force
```

## License

TBD
