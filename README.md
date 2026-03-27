# Forge

> *Forge your focus. Block distractions. No compromises.*

Forge is a modern macOS app that blocks distracting websites and apps with an unbypassable commitment mechanism. It is the spiritual successor to [SelfControl](https://github.com/SelfControlApp/selfcontrol), rebuilt from the ground up in Swift/SwiftUI for macOS 15+.

## Key Features

- **Website blocking** with DNS-over-HTTPS bypass protection (Network Extension)
- **App blocking** at the kernel level (EndpointSecurity)
- **Three-layer enforcement** — blocks survive extension disabling, app deletion, and reboots
- **Profiles** — named blocking configurations (Social Media, Work Mode, Study, etc.)
- **Recurring schedules** — blocks start automatically on a weekly cadence
- **Usage insights** — focus time, blocked attempts, streaks (Swift Charts)
- **Cross-device sync** — profiles and schedules sync via iCloud
- **Menu bar-first UX** — SwiftUI, Liquid Glass ready, keyboard-driven
- **Desktop widgets** — interactive WidgetKit widgets
- **Privacy-first** — all data local, optional iCloud sync, optional crash reporting
- **Clean restoration** — every system modification tracked and fully reversible

## Architecture

```
Forge.app (SwiftUI)
├── ForgeFilterExtension.systemextension (NE + DNS Proxy + EndpointSecurity)
├── ForgeHelper (privileged, PF rules + cleanup timer)
├── forge-cli (command-line tool)
└── ForgeWidget (WidgetKit)
```

## Documentation

- [Design Specification](docs/design-spec.md)
- [Competitive Research](docs/competitive-research.md)
- [SelfControl v4 Feature Inventory](docs/v4-feature-inventory.md)
- [SelfControl v4 Architectural Review](docs/architectural-review.md)

## Requirements

- macOS 15 (Sequoia) or later
- Xcode 16+
- Apple Developer Program membership (for Network Extension and EndpointSecurity entitlements)

## License

TBD
