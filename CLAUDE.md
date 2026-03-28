# Forge — Claude Code Guidelines

## Project Overview
Forge is a macOS focus app that blocks distracting websites and apps with an unbypassable commitment mechanism. It is a complete rewrite of SelfControl in Swift/SwiftUI for macOS 15+.

## Architecture
- **Forge** — SwiftUI menu bar app (main target)
- **ForgeFilterExtension** — System Extension (NEFilterDataProvider + NEDNSProxyProvider + EndpointSecurity)
- **ForgeHelper** — Privileged helper (SMJobBless, runs as root, manages PF rules)
- **forge-cli** — Command-line tool (Swift ArgumentParser)
- **ForgeWidget** — WidgetKit extension
- Three enforcement layers: System Extension → PF Firewall → Polling Daemon

## Build System
- XcodeGen generates Forge.xcodeproj from `project.yml`
- Run `xcodegen generate` after changing targets or build settings
- Build: `xcodebuild -scheme Forge -destination 'platform=macOS' build`
- Test: `xcodebuild -scheme Forge test -only-testing:ForgeTests`

## Conventions
- Swift 6 with strict concurrency checking
- macOS 15+ deployment target
- SwiftUI for all UI, SwiftData for persistence
- Swift Testing framework (not XCTest) for unit/integration tests
- XCTest for UI tests only
- App Group: `group.app.forge`
- Bundle ID prefix: `app.forge`

## Key Files
- `docs/design-spec.md` — Complete architecture specification
- `docs/implementation-plan.md` — 9-phase implementation plan
- `project.yml` — XcodeGen project definition
- `.swiftlint.yml` — Linting rules
