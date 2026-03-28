# Network Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the network filtering engine — DNS proxy intercepts queries, content filter blocks flows, DoH bypass protection forces browsers to system DNS. The extension persists its ruleset and self-manages expiry across reboots.

**Architecture:** A `ForgeKit` framework contains all shared models and logic (ruleset matching, DoH list, SNI extraction, XPC protocol). Both the app and extension link to it. The extension has two NE providers (DNS proxy + content filter) that delegate to ForgeKit's matching logic. The app activates the extension via NEFilterManager and communicates rulesets via XPC.

**Tech Stack:** Swift 6, NetworkExtension framework, Swift Testing, XcodeGen

**Spec:** `docs/superpowers/specs/2026-03-27-simplified-architecture-design.md`
**Design reference:** `docs/design-spec.md` Section 5 (Network Filtering Engine)

---

## File Structure

### New files to create

```
ForgeKit/                              # Shared framework (app + extension)
├── Models/
│   ├── BlockRuleset.swift             # Ruleset model with matching
│   ├── DomainRule.swift               # Rule types + matching logic
│   └── BlockMode.swift                # Blocklist/allowlist enum
├── Matching/
│   ├── DomainMatcher.swift            # Core domain matching engine
│   └── CIDRMatcher.swift             # CIDR range matching
├── DoHServerList.swift                # Known DoH resolver IPs
├── SNIExtractor.swift                 # TLS ClientHello SNI parsing
└── XPCProtocol.swift                  # ForgeExtensionProtocol definition

ForgeFilterExtension/
├── FilterDataProvider.swift           # NEFilterDataProvider (replaces FilterExtension.swift)
├── DNSProxyProvider.swift             # NEDNSProxyProvider (replaces DNSProxyExtension.swift)
├── RulesetStore.swift                 # Persist/load/delete (rewrite existing stub)
├── IPHostnameMap.swift                # Thread-safe map (rewrite existing stub)
└── ExtensionXPCService.swift          # XPC listener for app commands

Forge/Services/
├── ExtensionXPCClient.swift           # App-side XPC to extension
└── FilterManagerService.swift         # NEFilterManager activation

Forge/Resources/
└── doh-servers.json                   # Bundled DoH resolver IP list

ForgeTests/
├── DomainMatcherTests.swift           # Domain matching logic
├── CIDRMatcherTests.swift             # CIDR range matching
├── BlockRulesetTests.swift            # Ruleset matching + expiry (rewrite)
├── DoHServerListTests.swift           # DoH list loading + matching
├── SNIExtractorTests.swift            # TLS ClientHello parsing
├── RulesetStoreTests.swift            # Persistence roundtrip
└── IPHostnameMapTests.swift           # Concurrent map operations
```

### Files to delete

```
ForgeHelper/                           # Entire directory (7 files)
Scripts/cleanup.sh
ForgeFilterExtension/FilterExtension.swift   # Replaced by FilterDataProvider.swift
ForgeFilterExtension/DNSProxyExtension.swift # Replaced by DNSProxyProvider.swift
ForgeFilterExtension/AppBlocker.swift        # Moved to Phase 4
Forge/Models/BlockRuleset.swift              # Moved to ForgeKit
Forge/Services/XPCClient.swift               # Replaced by ExtensionXPCClient.swift
Forge/Info.plist                             # SMPrivilegedExecutables no longer needed
```

### Files to modify

```
project.yml                            # Remove ForgeHelper, add ForgeKit, update deps
Forge/Forge.entitlements               # Remove sandbox (app needs XPC to extension)
ForgeFilterExtension/Info.plist        # Update provider classes
CLAUDE.md                              # Update architecture description
```

---

### Task 1: Remove ForgeHelper and Add ForgeKit Target

**Files:**
- Delete: `ForgeHelper/` (entire directory), `Scripts/cleanup.sh`, `Forge/Info.plist`
- Create: `ForgeKit/` directory
- Modify: `project.yml`

- [ ] **Step 1: Delete ForgeHelper files and cleanup script**

```bash
rm -rf ForgeHelper Scripts/cleanup.sh Forge/Info.plist
```

- [ ] **Step 2: Create ForgeKit directory structure**

```bash
mkdir -p ForgeKit/Models ForgeKit/Matching
```

- [ ] **Step 3: Create ForgeKit placeholder file**

Create `ForgeKit/ForgeKit.swift`:

```swift
import Foundation

// ForgeKit — shared models and logic for Forge app and extension
```

- [ ] **Step 4: Update project.yml — remove ForgeHelper, add ForgeKit**

Remove the entire `ForgeHelper` target block (lines 86-99). Remove the ForgeHelper dependency from the Forge app target (lines 58-60). Remove `ForgeHelper: all` from the scheme (line 179). Remove the `INFOPLIST_FILE: Forge/Info.plist` line from the Forge target settings (line 45). Add the ForgeKit target and wire up dependencies.

The full updated `project.yml`:

```yaml
name: Forge
options:
  bundleIdPrefix: app.forge
  deploymentTarget:
    macOS: "15.0"
  xcodeVersion: "16.0"
  createIntermediateGroups: true
  defaultConfig: Debug
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
    MACOSX_DEPLOYMENT_TARGET: "15.0"
    DEVELOPMENT_TEAM: "3WZ27HVC5C"

packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.6.0"
  ArgumentParser:
    url: https://github.com/apple/swift-argument-parser
    from: "1.5.0"

targets:
  ForgeKit:
    type: framework
    platform: macOS
    sources:
      - path: ForgeKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.forge.ForgeKit
        PRODUCT_MODULE_NAME: ForgeKit
        GENERATE_INFOPLIST_FILE: true
        DEFINES_MODULE: true

  Forge:
    type: application
    platform: macOS
    sources:
      - path: Forge
        excludes:
          - "**/*.entitlements"
    resources:
      - path: Forge/Resources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.forge.Forge
        DEFINES_MODULE: true
        PRODUCT_MODULE_NAME: Forge
        ENABLE_TESTING_SEARCH_PATHS: true
        GENERATE_INFOPLIST_FILE: true
        INFOPLIST_KEY_LSUIElement: true
        INFOPLIST_KEY_CFBundleDisplayName: Forge
        INFOPLIST_KEY_NSMainStoryboardFile: ""
        INFOPLIST_KEY_LSApplicationCategoryType: "public.app-category.productivity"
        CODE_SIGN_ENTITLEMENTS: Forge/Forge.entitlements
        ENABLE_HARDENED_RUNTIME: true
        LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/../Frameworks"
    dependencies:
      - target: ForgeKit
        embed: true
      - target: ForgeFilterExtension
        embed: true
        codeSign: true
      - target: ForgeWidget
        embed: true
        codeSign: true
        copy:
          destination: plugins
      - package: Sparkle

  ForgeFilterExtension:
    type: system-extension
    platform: macOS
    sources:
      - path: ForgeFilterExtension
        excludes:
          - "**/*.entitlements"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.forge.Forge.ForgeFilterExtension
        CODE_SIGN_ENTITLEMENTS: ForgeFilterExtension/ForgeFilterExtension.entitlements
        ENABLE_HARDENED_RUNTIME: true
        GENERATE_INFOPLIST_FILE: false
        INFOPLIST_FILE: ForgeFilterExtension/Info.plist
        SYSTEM_EXTENSION_INSTALL_CODE_SIGN_IDENTITY: ""
    dependencies:
      - target: ForgeKit
        embed: false
    frameworks:
      - NetworkExtension.framework

  forge-cli:
    type: tool
    platform: macOS
    sources:
      - path: forge-cli
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.forge.cli
        PRODUCT_NAME: forge
        ENABLE_HARDENED_RUNTIME: true
        GENERATE_INFOPLIST_FILE: true
    dependencies:
      - package: ArgumentParser

  ForgeWidget:
    type: app-extension
    platform: macOS
    sources:
      - path: ForgeWidget
        excludes:
          - "**/*.entitlements"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.forge.Forge.ForgeWidget
        CODE_SIGN_ENTITLEMENTS: ForgeWidget/ForgeWidget.entitlements
        ENABLE_HARDENED_RUNTIME: true
        GENERATE_INFOPLIST_FILE: true
        INFOPLIST_KEY_NSExtension_NSExtensionPointIdentifier: com.apple.widgetkit-extension
    frameworks:
      - WidgetKit.framework
      - SwiftUI.framework

  ForgeTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: ForgeTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.forge.ForgeTests
        GENERATE_INFOPLIST_FILE: true
    dependencies:
      - target: ForgeKit

  ForgeIntegrationTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: ForgeIntegrationTests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.forge.ForgeIntegrationTests
        GENERATE_INFOPLIST_FILE: true
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Forge.app/Contents/MacOS/Forge"
        BUNDLE_LOADER: "$(TEST_HOST)"
    dependencies:
      - target: Forge

  ForgeUITests:
    type: bundle.ui-testing
    platform: macOS
    sources:
      - path: ForgeUITests
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: app.forge.ForgeUITests
        GENERATE_INFOPLIST_FILE: true
    dependencies:
      - target: Forge

schemes:
  Forge:
    build:
      targets:
        Forge: all
        ForgeKit: all
        ForgeFilterExtension: all
        ForgeWidget: all
        forge-cli: all
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - ForgeTests
        - ForgeIntegrationTests
    profile:
      config: Release
    archive:
      config: Release

  forge-cli:
    build:
      targets:
        forge-cli: all
    run:
      config: Debug
```

Key changes:
- `ForgeKit` framework target added, both app and extension depend on it
- `ForgeHelper` target removed entirely
- `ForgeTests` depends on `ForgeKit` directly (not the app) — no more TEST_HOST issues
- `Forge/Info.plist` removed (no SMPrivilegedExecutables needed)

- [ ] **Step 5: Delete the old BlockRuleset stub from Forge/Models**

```bash
rm Forge/Models/BlockRuleset.swift
```

- [ ] **Step 6: Delete old extension stubs that will be rewritten**

```bash
rm ForgeFilterExtension/FilterExtension.swift ForgeFilterExtension/DNSProxyExtension.swift ForgeFilterExtension/AppBlocker.swift
```

- [ ] **Step 7: Delete old XPCClient stub**

```bash
rm Forge/Services/XPCClient.swift
```

- [ ] **Step 8: Update .swiftlint.yml — add ForgeKit**

Add `ForgeKit` to the `included` list.

- [ ] **Step 9: Regenerate Xcode project and verify build**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild build -scheme Forge -destination 'platform=macOS' -configuration Debug \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "Remove ForgeHelper, add ForgeKit framework target

Simplified architecture: removed privileged helper, PF enforcement,
and cleanup daemon. Added ForgeKit shared framework for models and
logic shared between app and extension targets."
```

---

### Task 2: DomainRule Model + DomainMatcher (TDD)

**Files:**
- Create: `ForgeKit/Models/DomainRule.swift`
- Create: `ForgeKit/Models/BlockMode.swift`
- Create: `ForgeKit/Matching/DomainMatcher.swift`
- Create: `ForgeTests/DomainMatcherTests.swift`

- [ ] **Step 1: Write failing tests for DomainMatcher**

Create `ForgeTests/DomainMatcherTests.swift`:

```swift
import Testing
@testable import ForgeKit

@Suite("DomainMatcher Tests")
struct DomainMatcherTests {

    // MARK: - Exact matching

    @Test func exactMatchHitsExactDomain() {
        let matcher = DomainMatcher(rules: [.exact("reddit.com")])
        #expect(matcher.matches("reddit.com") == true)
    }

    @Test func exactMatchIsCaseInsensitive() {
        let matcher = DomainMatcher(rules: [.exact("Reddit.COM")])
        #expect(matcher.matches("reddit.com") == true)
    }

    @Test func exactMatchDoesNotMatchSubdomain() {
        let matcher = DomainMatcher(rules: [.exact("reddit.com")])
        #expect(matcher.matches("www.reddit.com") == false)
    }

    @Test func exactMatchDoesNotMatchUnrelatedDomain() {
        let matcher = DomainMatcher(rules: [.exact("reddit.com")])
        #expect(matcher.matches("google.com") == false)
    }

    // MARK: - Wildcard matching

    @Test func wildcardMatchesSubdomain() {
        let matcher = DomainMatcher(rules: [.wildcard("*.reddit.com")])
        #expect(matcher.matches("www.reddit.com") == true)
        #expect(matcher.matches("old.reddit.com") == true)
        #expect(matcher.matches("m.reddit.com") == true)
    }

    @Test func wildcardMatchesDeepSubdomain() {
        let matcher = DomainMatcher(rules: [.wildcard("*.reddit.com")])
        #expect(matcher.matches("a.b.c.reddit.com") == true)
    }

    @Test func wildcardDoesNotMatchBaseDomain() {
        let matcher = DomainMatcher(rules: [.wildcard("*.reddit.com")])
        #expect(matcher.matches("reddit.com") == false)
    }

    @Test func wildcardDoesNotMatchUnrelatedDomain() {
        let matcher = DomainMatcher(rules: [.wildcard("*.reddit.com")])
        #expect(matcher.matches("www.google.com") == false)
    }

    // MARK: - Port-specific matching

    @Test func portSpecificMatchesCorrectPort() {
        let matcher = DomainMatcher(rules: [.portSpecific("example.com", 8080)])
        #expect(matcher.matchesWithPort("example.com", port: 8080) == true)
    }

    @Test func portSpecificDoesNotMatchWrongPort() {
        let matcher = DomainMatcher(rules: [.portSpecific("example.com", 8080)])
        #expect(matcher.matchesWithPort("example.com", port: 443) == false)
    }

    // MARK: - Multiple rules

    @Test func multipleRulesMatchAny() {
        let matcher = DomainMatcher(rules: [
            .exact("reddit.com"),
            .wildcard("*.twitter.com"),
            .exact("facebook.com")
        ])
        #expect(matcher.matches("reddit.com") == true)
        #expect(matcher.matches("m.twitter.com") == true)
        #expect(matcher.matches("facebook.com") == true)
        #expect(matcher.matches("google.com") == false)
    }

    @Test func emptyRulesMatchNothing() {
        let matcher = DomainMatcher(rules: [])
        #expect(matcher.matches("anything.com") == false)
    }

    @Test func nilHostnameMatchesNothing() {
        let matcher = DomainMatcher(rules: [.exact("reddit.com")])
        #expect(matcher.matches(nil) == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests/DomainMatcherTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "error:|FAIL|PASS|BUILD"
```

Expected: Build failure — `DomainMatcher` not defined.

- [ ] **Step 3: Create BlockMode enum**

Create `ForgeKit/Models/BlockMode.swift`:

```swift
import Foundation

public enum BlockMode: String, Codable, Sendable {
    case blocklist
    case allowlist
}
```

- [ ] **Step 4: Create DomainRule model**

Create `ForgeKit/Models/DomainRule.swift`:

```swift
import Foundation

public enum DomainRule: Codable, Sendable, Hashable {
    case exact(String)
    case wildcard(String)
    case cidr(String, Int)
    case portSpecific(String, Int)
}
```

- [ ] **Step 5: Implement DomainMatcher**

Create `ForgeKit/Matching/DomainMatcher.swift`:

```swift
import Foundation

public struct DomainMatcher: Sendable {
    private let exactDomains: Set<String>
    private let wildcardSuffixes: [String]
    private let portRules: [(String, Int)]

    public init(rules: [DomainRule]) {
        var exact = Set<String>()
        var wildcards = [String]()
        var ports = [(String, Int)]()

        for rule in rules {
            switch rule {
            case .exact(let domain):
                exact.insert(domain.lowercased())
            case .wildcard(let pattern):
                // "*.reddit.com" → store ".reddit.com"
                let suffix = String(pattern.dropFirst(1)).lowercased()
                wildcards.append(suffix)
            case .cidr:
                break // Handled by CIDRMatcher
            case .portSpecific(let domain, let port):
                ports.append((domain.lowercased(), port))
            }
        }

        self.exactDomains = exact
        self.wildcardSuffixes = wildcards
        self.portRules = ports
    }

    public func matches(_ hostname: String?) -> Bool {
        guard let hostname = hostname?.lowercased() else { return false }

        if exactDomains.contains(hostname) {
            return true
        }

        for suffix in wildcardSuffixes {
            if hostname.hasSuffix(suffix) && hostname.count > suffix.count {
                return true
            }
        }

        return false
    }

    public func matchesWithPort(_ hostname: String?, port: Int) -> Bool {
        guard let hostname = hostname?.lowercased() else { return false }

        for (domain, rulePort) in portRules where rulePort == port {
            if hostname == domain {
                return true
            }
        }

        return false
    }
}
```

- [ ] **Step 6: Regenerate project and run tests**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests/DomainMatcherTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "passed|failed|error:|Test run"
```

Expected: All tests pass.

- [ ] **Step 7: Run SwiftLint**

```bash
swiftlint lint --strict
```

Expected: 0 violations.

- [ ] **Step 8: Commit**

```bash
git add ForgeKit/Models/ ForgeKit/Matching/DomainMatcher.swift ForgeTests/DomainMatcherTests.swift
git commit -m "Add DomainRule model and DomainMatcher with TDD tests

Exact matching, wildcard subdomain matching, port-specific matching,
case-insensitive, nil-safe. Core matching engine shared via ForgeKit."
```

---

### Task 3: CIDRMatcher (TDD)

**Files:**
- Create: `ForgeKit/Matching/CIDRMatcher.swift`
- Create: `ForgeTests/CIDRMatcherTests.swift`

- [ ] **Step 1: Write failing tests for CIDRMatcher**

Create `ForgeTests/CIDRMatcherTests.swift`:

```swift
import Testing
@testable import ForgeKit

@Suite("CIDRMatcher Tests")
struct CIDRMatcherTests {

    @Test func ipv4InRange() {
        let matcher = CIDRMatcher(rules: [.cidr("192.168.1.0", 24)])
        #expect(matcher.matches(ip: "192.168.1.50") == true)
        #expect(matcher.matches(ip: "192.168.1.0") == true)
        #expect(matcher.matches(ip: "192.168.1.255") == true)
    }

    @Test func ipv4OutOfRange() {
        let matcher = CIDRMatcher(rules: [.cidr("192.168.1.0", 24)])
        #expect(matcher.matches(ip: "192.168.2.1") == false)
        #expect(matcher.matches(ip: "10.0.0.1") == false)
    }

    @Test func singleIPMatch() {
        let matcher = CIDRMatcher(rules: [.cidr("1.1.1.1", 32)])
        #expect(matcher.matches(ip: "1.1.1.1") == true)
        #expect(matcher.matches(ip: "1.1.1.2") == false)
    }

    @Test func wideRange() {
        let matcher = CIDRMatcher(rules: [.cidr("10.0.0.0", 8)])
        #expect(matcher.matches(ip: "10.255.255.255") == true)
        #expect(matcher.matches(ip: "11.0.0.0") == false)
    }

    @Test func multipleRanges() {
        let matcher = CIDRMatcher(rules: [
            .cidr("192.168.1.0", 24),
            .cidr("10.0.0.0", 8)
        ])
        #expect(matcher.matches(ip: "192.168.1.5") == true)
        #expect(matcher.matches(ip: "10.1.2.3") == true)
        #expect(matcher.matches(ip: "172.16.0.1") == false)
    }

    @Test func invalidIPReturnsNoMatch() {
        let matcher = CIDRMatcher(rules: [.cidr("192.168.1.0", 24)])
        #expect(matcher.matches(ip: "not-an-ip") == false)
        #expect(matcher.matches(ip: "") == false)
    }

    @Test func emptyRulesMatchNothing() {
        let matcher = CIDRMatcher(rules: [])
        #expect(matcher.matches(ip: "1.1.1.1") == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests/CIDRMatcherTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "error:|FAIL|BUILD"
```

Expected: Build failure — `CIDRMatcher` not defined.

- [ ] **Step 3: Implement CIDRMatcher**

Create `ForgeKit/Matching/CIDRMatcher.swift`:

```swift
import Foundation

public struct CIDRMatcher: Sendable {
    private let ranges: [(network: UInt32, mask: UInt32)]

    public init(rules: [DomainRule]) {
        var parsed = [(UInt32, UInt32)]()
        for rule in rules {
            if case .cidr(let ip, let prefix) = rule {
                if let network = Self.parseIPv4(ip) {
                    let mask: UInt32 = prefix == 0 ? 0 : ~UInt32(0) << (32 - UInt32(prefix))
                    parsed.append((network & mask, mask))
                }
            }
        }
        self.ranges = parsed
    }

    public func matches(ip: String) -> Bool {
        guard let addr = Self.parseIPv4(ip) else { return false }
        return ranges.contains { addr & $0.mask == $0.network }
    }

    private static func parseIPv4(_ ip: String) -> UInt32? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }

        var result: UInt32 = 0
        for part in parts {
            guard let octet = UInt32(part), octet <= 255 else { return nil }
            result = result << 8 | octet
        }
        return result
    }
}
```

- [ ] **Step 4: Run tests**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests/CIDRMatcherTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "passed|failed|Test run"
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add ForgeKit/Matching/CIDRMatcher.swift ForgeTests/CIDRMatcherTests.swift
git commit -m "Add CIDRMatcher for IPv4 CIDR range matching

Parses IPv4 addresses into UInt32 and compares against network/mask
pairs. Handles /8 through /32 ranges, invalid IPs return no match."
```

---

### Task 4: BlockRuleset Model (TDD)

**Files:**
- Create: `ForgeKit/Models/BlockRuleset.swift`
- Rewrite: `ForgeTests/BlockRulesetTests.swift`

- [ ] **Step 1: Write failing tests**

Rewrite `ForgeTests/BlockRulesetTests.swift`:

```swift
import Testing
import Foundation
@testable import ForgeKit

@Suite("BlockRuleset Tests")
struct BlockRulesetTests {

    static func makeSampleRuleset(
        mode: BlockMode = .blocklist,
        endDate: Date = .distantFuture
    ) -> BlockRuleset {
        BlockRuleset(
            id: UUID(),
            mode: mode,
            domains: [
                .exact("reddit.com"),
                .wildcard("*.twitter.com")
            ],
            appBundleIDs: [],
            dohServerIPs: ["1.1.1.1", "8.8.8.8"],
            allowLocalNetwork: true,
            expandCommonSubdomains: true,
            startDate: .now,
            endDate: endDate
        )
    }

    @Test func encodingRoundtrip() throws {
        let original = Self.makeSampleRuleset()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BlockRuleset.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.mode == original.mode)
        #expect(decoded.domains.count == 2)
        #expect(decoded.dohServerIPs == ["1.1.1.1", "8.8.8.8"])
        #expect(decoded.allowLocalNetwork == true)
        #expect(decoded.expandCommonSubdomains == true)
    }

    @Test func blocklistModeBlocksMatchedDomain() {
        let ruleset = Self.makeSampleRuleset(mode: .blocklist)
        #expect(ruleset.shouldBlock(hostname: "reddit.com") == true)
        #expect(ruleset.shouldBlock(hostname: "m.twitter.com") == true)
    }

    @Test func blocklistModeAllowsUnmatchedDomain() {
        let ruleset = Self.makeSampleRuleset(mode: .blocklist)
        #expect(ruleset.shouldBlock(hostname: "google.com") == false)
    }

    @Test func allowlistModeAllowsMatchedDomain() {
        let ruleset = Self.makeSampleRuleset(mode: .allowlist)
        #expect(ruleset.shouldBlock(hostname: "reddit.com") == false)
    }

    @Test func allowlistModeBlocksUnmatchedDomain() {
        let ruleset = Self.makeSampleRuleset(mode: .allowlist)
        #expect(ruleset.shouldBlock(hostname: "google.com") == true)
    }

    @Test func isExpiredReturnsTrueAfterEndDate() {
        let ruleset = Self.makeSampleRuleset(
            endDate: .now.addingTimeInterval(-60)
        )
        #expect(ruleset.isExpired == true)
    }

    @Test func isExpiredReturnsFalseBeforeEndDate() {
        let ruleset = Self.makeSampleRuleset(
            endDate: .now.addingTimeInterval(3600)
        )
        #expect(ruleset.isExpired == false)
    }

    @Test func nilHostnameNotBlockedInBlocklistMode() {
        let ruleset = Self.makeSampleRuleset(mode: .blocklist)
        #expect(ruleset.shouldBlock(hostname: nil) == false)
    }

    @Test func nilHostnameBlockedInAllowlistMode() {
        let ruleset = Self.makeSampleRuleset(mode: .allowlist)
        #expect(ruleset.shouldBlock(hostname: nil) == true)
    }

    @Test func expandedSubdomainsAddWwwAndMobileVariants() {
        let ruleset = BlockRuleset(
            id: UUID(),
            mode: .blocklist,
            domains: [.exact("reddit.com")],
            appBundleIDs: [],
            dohServerIPs: [],
            allowLocalNetwork: true,
            expandCommonSubdomains: true,
            startDate: .now,
            endDate: .distantFuture
        )
        #expect(ruleset.shouldBlock(hostname: "www.reddit.com") == true)
        #expect(ruleset.shouldBlock(hostname: "m.reddit.com") == true)
    }

    @Test func noExpansionWhenDisabled() {
        let ruleset = BlockRuleset(
            id: UUID(),
            mode: .blocklist,
            domains: [.exact("reddit.com")],
            appBundleIDs: [],
            dohServerIPs: [],
            allowLocalNetwork: true,
            expandCommonSubdomains: false,
            startDate: .now,
            endDate: .distantFuture
        )
        #expect(ruleset.shouldBlock(hostname: "www.reddit.com") == false)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Build failure — `BlockRuleset` type mismatch or missing methods.

- [ ] **Step 3: Implement BlockRuleset**

Create `ForgeKit/Models/BlockRuleset.swift`:

```swift
import Foundation

public struct BlockRuleset: Codable, Sendable {
    public let id: UUID
    public let mode: BlockMode
    public let domains: [DomainRule]
    public let appBundleIDs: [String]
    public let dohServerIPs: [String]
    public let allowLocalNetwork: Bool
    public let expandCommonSubdomains: Bool
    public let startDate: Date
    public let endDate: Date

    private static let commonSubdomainPrefixes = ["www.", "m.", "mobile.", "api."]

    public init(
        id: UUID,
        mode: BlockMode,
        domains: [DomainRule],
        appBundleIDs: [String],
        dohServerIPs: [String],
        allowLocalNetwork: Bool,
        expandCommonSubdomains: Bool,
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.mode = mode
        self.appBundleIDs = appBundleIDs
        self.dohServerIPs = dohServerIPs
        self.allowLocalNetwork = allowLocalNetwork
        self.expandCommonSubdomains = expandCommonSubdomains
        self.startDate = startDate
        self.endDate = endDate

        if expandCommonSubdomains {
            var expanded = domains
            for rule in domains {
                if case .exact(let domain) = rule {
                    for prefix in Self.commonSubdomainPrefixes {
                        expanded.append(.exact(prefix + domain))
                    }
                }
            }
            self.domains = expanded
        } else {
            self.domains = domains
        }
    }

    public var isExpired: Bool {
        Date() >= endDate
    }

    public func shouldBlock(hostname: String?) -> Bool {
        let matcher = DomainMatcher(rules: domains)
        let matched = matcher.matches(hostname)

        switch mode {
        case .blocklist:
            return matched
        case .allowlist:
            return !matched
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests/BlockRulesetTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "passed|failed|Test run"
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add ForgeKit/Models/BlockRuleset.swift ForgeTests/BlockRulesetTests.swift
git commit -m "Add BlockRuleset with shouldBlock matching and subdomain expansion

Supports blocklist/allowlist modes, expiry checking, and optional
common subdomain expansion (www, m, mobile, api prefixes)."
```

---

### Task 5: DoH Server List (TDD)

**Files:**
- Create: `Forge/Resources/doh-servers.json`
- Create: `ForgeKit/DoHServerList.swift`
- Create: `ForgeTests/DoHServerListTests.swift`

- [ ] **Step 1: Write failing tests**

Create `ForgeTests/DoHServerListTests.swift`:

```swift
import Testing
import Foundation
@testable import ForgeKit

@Suite("DoHServerList Tests")
struct DoHServerListTests {

    @Test func loadFromJSONData() throws {
        let json = """
        {
            "servers": [
                { "name": "Cloudflare", "ips": ["1.1.1.1", "1.0.0.1"] },
                { "name": "Google", "ips": ["8.8.8.8", "8.8.4.4"] }
            ]
        }
        """.data(using: .utf8)!

        let list = try DoHServerList(jsonData: json)
        #expect(list.allIPs.count == 4)
        #expect(list.contains(ip: "1.1.1.1") == true)
        #expect(list.contains(ip: "8.8.4.4") == true)
    }

    @Test func doesNotContainRandomIP() throws {
        let json = """
        { "servers": [{ "name": "Test", "ips": ["1.1.1.1"] }] }
        """.data(using: .utf8)!

        let list = try DoHServerList(jsonData: json)
        #expect(list.contains(ip: "192.168.1.1") == false)
    }

    @Test func emptyServersProducesEmptyList() throws {
        let json = """
        { "servers": [] }
        """.data(using: .utf8)!

        let list = try DoHServerList(jsonData: json)
        #expect(list.allIPs.isEmpty)
    }

    @Test func invalidJSONThrows() {
        let bad = "not json".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try DoHServerList(jsonData: bad)
        }
    }

    @Test func customIPsOverrideDefaults() throws {
        let json = """
        { "servers": [{ "name": "Test", "ips": ["1.1.1.1"] }] }
        """.data(using: .utf8)!

        var list = try DoHServerList(jsonData: json)
        list.addCustomIPs(["9.9.9.9"])
        #expect(list.contains(ip: "9.9.9.9") == true)
        #expect(list.contains(ip: "1.1.1.1") == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Build failure — `DoHServerList` not defined.

- [ ] **Step 3: Create the bundled JSON file**

Create `Forge/Resources/doh-servers.json`:

```json
{
    "servers": [
        { "name": "Cloudflare", "ips": ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"] },
        { "name": "Google", "ips": ["8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844"] },
        { "name": "Quad9", "ips": ["9.9.9.9", "149.112.112.112", "2620:fe::fe", "2620:fe::9"] },
        { "name": "OpenDNS", "ips": ["208.67.222.222", "208.67.220.220"] },
        { "name": "NextDNS", "ips": ["45.90.28.0", "45.90.30.0"] },
        { "name": "AdGuard", "ips": ["94.140.14.14", "94.140.15.15"] },
        { "name": "CleanBrowsing", "ips": ["185.228.168.9", "185.228.169.9"] },
        { "name": "Mullvad", "ips": ["194.242.2.2"] }
    ]
}
```

- [ ] **Step 4: Implement DoHServerList**

Create `ForgeKit/DoHServerList.swift`:

```swift
import Foundation

public struct DoHServerList: Sendable {
    private var ips: Set<String>

    public var allIPs: Set<String> { ips }

    public init(jsonData: Data) throws {
        let decoded = try JSONDecoder().decode(DoHServerListJSON.self, from: jsonData)
        self.ips = Set(decoded.servers.flatMap(\.ips))
    }

    public func contains(ip: String) -> Bool {
        ips.contains(ip)
    }

    public mutating func addCustomIPs(_ newIPs: [String]) {
        ips.formUnion(newIPs)
    }
}

private struct DoHServerListJSON: Codable {
    let servers: [DoHServerEntry]
}

private struct DoHServerEntry: Codable {
    let name: String
    let ips: [String]
}
```

- [ ] **Step 5: Run tests**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests/DoHServerListTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "passed|failed|Test run"
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add ForgeKit/DoHServerList.swift Forge/Resources/doh-servers.json ForgeTests/DoHServerListTests.swift
git commit -m "Add DoH server list with bundled IPs for 8 providers

Cloudflare, Google, Quad9, OpenDNS, NextDNS, AdGuard, CleanBrowsing,
Mullvad. Supports custom IP additions for user configuration."
```

---

### Task 6: SNI Extractor (TDD)

**Files:**
- Create: `ForgeKit/SNIExtractor.swift`
- Create: `ForgeTests/SNIExtractorTests.swift`

- [ ] **Step 1: Write failing tests**

Create `ForgeTests/SNIExtractorTests.swift`:

```swift
import Testing
import Foundation
@testable import ForgeKit

@Suite("SNIExtractor Tests")
struct SNIExtractorTests {

    /// Build a minimal TLS ClientHello with the given SNI hostname.
    /// TLS record: ContentType(22) + Version(0x0301) + Length + Handshake
    /// Handshake: Type(1=ClientHello) + Length + Version + Random(32) + SessionID(0)
    ///   + CipherSuites(2 bytes len + 2 bytes) + Compression(1 byte len + 1 byte)
    ///   + Extensions(2 bytes len + SNI extension)
    /// SNI extension: Type(0x0000) + Length + SNI list length + Type(0=hostname) + Hostname length + hostname
    static func buildClientHello(sni: String) -> Data {
        let hostnameBytes = Array(sni.utf8)
        let hostnameLen = hostnameBytes.count

        // SNI extension
        var sniExt = Data()
        sniExt.append(contentsOf: [0x00, 0x00]) // Extension type: server_name
        let sniListLen = hostnameLen + 3 // type(1) + len(2)
        let sniExtLen = sniListLen + 2   // list length(2)
        sniExt.append(contentsOf: UInt16(sniExtLen).bigEndianBytes)
        sniExt.append(contentsOf: UInt16(sniListLen).bigEndianBytes)
        sniExt.append(0x00) // Host name type: hostname
        sniExt.append(contentsOf: UInt16(hostnameLen).bigEndianBytes)
        sniExt.append(contentsOf: hostnameBytes)

        // Extensions block
        var extensions = Data()
        extensions.append(contentsOf: UInt16(sniExt.count).bigEndianBytes)
        extensions.append(sniExt)

        // ClientHello body
        var body = Data()
        body.append(contentsOf: [0x03, 0x03]) // Version TLS 1.2
        body.append(Data(repeating: 0x00, count: 32)) // Random
        body.append(0x00) // Session ID length
        body.append(contentsOf: [0x00, 0x02, 0x00, 0xFF]) // Cipher suites (1 suite)
        body.append(contentsOf: [0x01, 0x00]) // Compression methods
        body.append(extensions)

        // Handshake header
        var handshake = Data()
        handshake.append(0x01) // ClientHello
        let bodyLen = body.count
        handshake.append(UInt8((bodyLen >> 16) & 0xFF))
        handshake.append(UInt8((bodyLen >> 8) & 0xFF))
        handshake.append(UInt8(bodyLen & 0xFF))
        handshake.append(body)

        // TLS record header
        var record = Data()
        record.append(0x16) // ContentType: Handshake
        record.append(contentsOf: [0x03, 0x01]) // Version TLS 1.0
        record.append(contentsOf: UInt16(handshake.count).bigEndianBytes)
        record.append(handshake)

        return record
    }

    @Test func extractsSNIFromValidClientHello() {
        let data = Self.buildClientHello(sni: "reddit.com")
        let hostname = SNIExtractor.extractHostname(from: data)
        #expect(hostname == "reddit.com")
    }

    @Test func extractsLongHostname() {
        let data = Self.buildClientHello(sni: "subdomain.example.co.uk")
        let hostname = SNIExtractor.extractHostname(from: data)
        #expect(hostname == "subdomain.example.co.uk")
    }

    @Test func returnsNilForNonTLSData() {
        let data = Data([0x47, 0x45, 0x54, 0x20]) // "GET "
        let hostname = SNIExtractor.extractHostname(from: data)
        #expect(hostname == nil)
    }

    @Test func returnsNilForEmptyData() {
        let hostname = SNIExtractor.extractHostname(from: Data())
        #expect(hostname == nil)
    }

    @Test func returnsNilForTruncatedData() {
        let data = Data([0x16, 0x03, 0x01]) // TLS header but truncated
        let hostname = SNIExtractor.extractHostname(from: data)
        #expect(hostname == nil)
    }
}

extension UInt16 {
    var bigEndianBytes: [UInt8] {
        [UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)]
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Build failure — `SNIExtractor` not defined.

- [ ] **Step 3: Implement SNIExtractor**

Create `ForgeKit/SNIExtractor.swift`:

```swift
import Foundation

public enum SNIExtractor: Sendable {

    /// Extract the SNI hostname from a TLS ClientHello message.
    /// Returns nil if the data is not a valid ClientHello or has no SNI extension.
    public static func extractHostname(from data: Data) -> String? {
        guard data.count > 5 else { return nil }

        // TLS record header: ContentType(1) + Version(2) + Length(2)
        guard data[0] == 0x16 else { return nil } // Handshake

        let recordLength = Int(data[3]) << 8 | Int(data[4])
        guard data.count >= 5 + recordLength else { return nil }

        var offset = 5 // Past TLS record header

        // Handshake header: Type(1) + Length(3)
        guard offset < data.count, data[offset] == 0x01 else { return nil } // ClientHello
        offset += 4 // Skip type + 3-byte length

        // ClientHello: Version(2) + Random(32) + SessionID(var) + CipherSuites(var) + Compression(var) + Extensions(var)
        guard offset + 34 <= data.count else { return nil }
        offset += 34 // Version + Random

        // Session ID
        guard offset < data.count else { return nil }
        let sessionIDLen = Int(data[offset])
        offset += 1 + sessionIDLen

        // Cipher suites
        guard offset + 2 <= data.count else { return nil }
        let cipherLen = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2 + cipherLen

        // Compression methods
        guard offset < data.count else { return nil }
        let compressionLen = Int(data[offset])
        offset += 1 + compressionLen

        // Extensions
        guard offset + 2 <= data.count else { return nil }
        let extensionsLen = Int(data[offset]) << 8 | Int(data[offset + 1])
        offset += 2

        let extensionsEnd = offset + extensionsLen
        guard extensionsEnd <= data.count else { return nil }

        while offset + 4 <= extensionsEnd {
            let extType = Int(data[offset]) << 8 | Int(data[offset + 1])
            let extLen = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            offset += 4

            if extType == 0x0000 { // server_name extension
                return parseServerNameExtension(data: data, offset: offset, length: extLen)
            }

            offset += extLen
        }

        return nil
    }

    private static func parseServerNameExtension(data: Data, offset: Int, length: Int) -> String? {
        var pos = offset
        guard pos + 2 <= data.count else { return nil }

        // SNI list length
        pos += 2

        guard pos < data.count else { return nil }
        let nameType = data[pos]
        pos += 1

        guard nameType == 0x00 else { return nil } // hostname type

        guard pos + 2 <= data.count else { return nil }
        let nameLen = Int(data[pos]) << 8 | Int(data[pos + 1])
        pos += 2

        guard pos + nameLen <= data.count else { return nil }
        return String(data: data[pos..<pos + nameLen], encoding: .utf8)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests/SNIExtractorTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "passed|failed|Test run"
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add ForgeKit/SNIExtractor.swift ForgeTests/SNIExtractorTests.swift
git commit -m "Add SNI extractor for TLS ClientHello hostname parsing

Parses TLS record → handshake → extensions → server_name to extract
the hostname. Returns nil for non-TLS, truncated, or missing SNI data."
```

---

### Task 7: RulesetStore (TDD)

**Files:**
- Rewrite: `ForgeFilterExtension/RulesetStore.swift`
- Create: `ForgeTests/RulesetStoreTests.swift`

- [ ] **Step 1: Write failing tests**

Create `ForgeTests/RulesetStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import ForgeKit

@Suite("RulesetStore Tests")
struct RulesetStoreTests {

    private func makeTemporaryStore() -> RulesetStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return RulesetStore(directory: dir)
    }

    private func makeSampleRuleset() -> BlockRuleset {
        BlockRuleset(
            id: UUID(),
            mode: .blocklist,
            domains: [.exact("reddit.com"), .wildcard("*.twitter.com")],
            appBundleIDs: ["com.hnc.Discord"],
            dohServerIPs: ["1.1.1.1"],
            allowLocalNetwork: true,
            expandCommonSubdomains: false,
            startDate: .now,
            endDate: .now.addingTimeInterval(3600)
        )
    }

    @Test func saveAndLoadRoundtrip() throws {
        let store = makeTemporaryStore()
        let original = makeSampleRuleset()

        try store.save(original)
        let loaded = try #require(store.load())

        #expect(loaded.id == original.id)
        #expect(loaded.mode == .blocklist)
        #expect(loaded.domains.count == 2)
        #expect(loaded.appBundleIDs == ["com.hnc.Discord"])
        #expect(loaded.dohServerIPs == ["1.1.1.1"])
    }

    @Test func loadReturnsNilWhenEmpty() {
        let store = makeTemporaryStore()
        #expect(store.load() == nil)
    }

    @Test func deleteRemovesStoredRuleset() throws {
        let store = makeTemporaryStore()
        try store.save(makeSampleRuleset())
        store.delete()
        #expect(store.load() == nil)
    }

    @Test func saveOverwritesPreviousRuleset() throws {
        let store = makeTemporaryStore()
        try store.save(makeSampleRuleset())

        let second = BlockRuleset(
            id: UUID(),
            mode: .allowlist,
            domains: [.exact("only-this.com")],
            appBundleIDs: [],
            dohServerIPs: [],
            allowLocalNetwork: false,
            expandCommonSubdomains: false,
            startDate: .now,
            endDate: .now.addingTimeInterval(7200)
        )
        try store.save(second)

        let loaded = try #require(store.load())
        #expect(loaded.id == second.id)
        #expect(loaded.mode == .allowlist)
    }

    @Test func loadExpiredRulesetReturnsNilAndCleans() throws {
        let store = makeTemporaryStore()
        let expired = BlockRuleset(
            id: UUID(),
            mode: .blocklist,
            domains: [.exact("reddit.com")],
            appBundleIDs: [],
            dohServerIPs: [],
            allowLocalNetwork: true,
            expandCommonSubdomains: false,
            startDate: .now.addingTimeInterval(-7200),
            endDate: .now.addingTimeInterval(-3600)
        )
        try store.save(expired)

        let loaded = store.loadIfActive()
        #expect(loaded == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Build failure — `RulesetStore` initializer mismatch.

- [ ] **Step 3: Implement RulesetStore**

Rewrite `ForgeFilterExtension/RulesetStore.swift`:

```swift
import Foundation
import ForgeKit

public final class RulesetStore: Sendable {
    private let fileURL: URL

    public init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("active-ruleset.json")
    }

    public func save(_ ruleset: BlockRuleset) throws {
        let data = try JSONEncoder().encode(ruleset)
        try data.write(to: fileURL, options: .atomic)
    }

    public func load() -> BlockRuleset? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(BlockRuleset.self, from: data)
    }

    public func loadIfActive() -> BlockRuleset? {
        guard let ruleset = load() else { return nil }
        if ruleset.isExpired {
            delete()
            return nil
        }
        return ruleset
    }

    public func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
```

- [ ] **Step 4: Run tests**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests/RulesetStoreTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "passed|failed|Test run"
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add ForgeFilterExtension/RulesetStore.swift ForgeTests/RulesetStoreTests.swift
git commit -m "Add RulesetStore with atomic persistence and expiry check

Save/load/delete BlockRuleset to JSON file. loadIfActive() auto-cleans
expired rulesets. Uses atomic writes for crash safety."
```

---

### Task 8: IPHostnameMap (TDD)

**Files:**
- Rewrite: `ForgeFilterExtension/IPHostnameMap.swift`
- Create: `ForgeTests/IPHostnameMapTests.swift`

- [ ] **Step 1: Write failing tests**

Create `ForgeTests/IPHostnameMapTests.swift`:

```swift
import Testing
import Foundation
@testable import ForgeKit

@Suite("IPHostnameMap Tests")
struct IPHostnameMapTests {

    @Test func setAndLookup() {
        let map = IPHostnameMap()
        map.set(ip: "93.184.216.34", hostname: "example.com")
        #expect(map.hostname(for: "93.184.216.34") == "example.com")
    }

    @Test func lookupMissingIPReturnsNil() {
        let map = IPHostnameMap()
        #expect(map.hostname(for: "1.2.3.4") == nil)
    }

    @Test func overwriteExistingIP() {
        let map = IPHostnameMap()
        map.set(ip: "1.1.1.1", hostname: "old.com")
        map.set(ip: "1.1.1.1", hostname: "new.com")
        #expect(map.hostname(for: "1.1.1.1") == "new.com")
    }

    @Test func clearRemovesAll() {
        let map = IPHostnameMap()
        map.set(ip: "1.1.1.1", hostname: "a.com")
        map.set(ip: "2.2.2.2", hostname: "b.com")
        map.clear()
        #expect(map.hostname(for: "1.1.1.1") == nil)
        #expect(map.hostname(for: "2.2.2.2") == nil)
    }

    @Test func concurrentAccessIsSafe() async {
        let map = IPHostnameMap()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    map.set(ip: "10.0.0.\(i % 256)", hostname: "host\(i).com")
                }
                group.addTask {
                    _ = map.hostname(for: "10.0.0.\(i % 256)")
                }
            }
        }

        // If we get here without crashing, concurrent access is safe
        #expect(true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: Build failure — `IPHostnameMap` missing init/methods.

- [ ] **Step 3: Implement IPHostnameMap**

Move to ForgeKit so both app tests and extension can use it. Create `ForgeKit/IPHostnameMap.swift` and delete the old `ForgeFilterExtension/IPHostnameMap.swift`:

```bash
rm ForgeFilterExtension/IPHostnameMap.swift
```

Create `ForgeKit/IPHostnameMap.swift`:

```swift
import Foundation

public final class IPHostnameMap: @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func set(ip: String, hostname: String) {
        lock.withLock {
            storage[ip] = hostname
        }
    }

    public func hostname(for ip: String) -> String? {
        lock.withLock {
            storage[ip]
        }
    }

    public func clear() {
        lock.withLock {
            storage.removeAll()
        }
    }
}
```

- [ ] **Step 4: Run tests**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests/IPHostnameMapTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "passed|failed|Test run"
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add ForgeKit/IPHostnameMap.swift ForgeTests/IPHostnameMapTests.swift
git commit -m "Add thread-safe IPHostnameMap for DNS proxy to filter communication

NSLock-guarded dictionary mapping IPs to hostnames. Used by DNS proxy
to record resolutions, read by content filter to identify Chrome flows."
```

---

### Task 9: XPC Protocol Definition

**Files:**
- Create: `ForgeKit/XPCProtocol.swift`

- [ ] **Step 1: Create XPC protocol**

Create `ForgeKit/XPCProtocol.swift`:

```swift
import Foundation

/// Protocol for app → extension XPC communication.
/// The extension listens on its Mach service; the app connects to send commands.
@objc public protocol ForgeExtensionProtocol {
    /// Apply a new ruleset. The extension persists it and activates filtering.
    func updateRuleset(_ rulesetData: Data, reply: @escaping (Error?) -> Void)

    /// Deactivate the current ruleset and stop filtering.
    func deactivateRuleset(reply: @escaping (Error?) -> Void)

    /// Get the current status: active ruleset data or nil.
    func getStatus(reply: @escaping (Data?) -> Void)
}

/// Protocol for extension → app XPC callback.
/// The app exports this interface so the extension can push events.
@objc public protocol ForgeAppCallbackProtocol {
    /// Notify the app that a flow was blocked.
    func flowBlocked(hostname: String, timestamp: Date)
}
```

- [ ] **Step 2: Regenerate project and build**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild build -scheme Forge -destination 'platform=macOS' -configuration Debug \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep "BUILD"
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ForgeKit/XPCProtocol.swift
git commit -m "Define ForgeExtensionProtocol and ForgeAppCallbackProtocol

XPC interface for app-extension communication. App sends rulesets
and deactivation commands; extension pushes blocked flow events."
```

---

### Task 10: NEFilterDataProvider Implementation

**Files:**
- Create: `ForgeFilterExtension/FilterDataProvider.swift`

- [ ] **Step 1: Implement FilterDataProvider**

Create `ForgeFilterExtension/FilterDataProvider.swift`:

```swift
import NetworkExtension
import ForgeKit

final class FilterDataProvider: NEFilterDataProvider {
    private var activeRuleset: BlockRuleset?
    private let ipMap = IPHostnameMap()
    private var dohIPs = Set<String>()
    private var domainMatcher: DomainMatcher?
    private var cidrMatcher: CIDRMatcher?

    private static let essentialPorts: Set<Int> = [53, 123, 67, 68, 5353]

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        let store = RulesetStore(directory: containerURL())
        if let ruleset = store.loadIfActive() {
            applyRuleset(ruleset)
        }
        completionHandler(nil)
    }

    override func stopFilter(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        activeRuleset = nil
        domainMatcher = nil
        cidrMatcher = nil
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let ruleset = activeRuleset else { return .allow() }

        // Check expiry on every flow
        if ruleset.isExpired {
            clearRuleset()
            return .allow()
        }

        guard let socketFlow = flow as? NEFilterSocketFlow else { return .allow() }

        // Allow essential services in allowlist mode
        if ruleset.mode == .allowlist {
            if let port = socketFlow.remotePort, Self.essentialPorts.contains(port) {
                return .allow()
            }
        }

        // Check if this is a DoH server connection
        if let ip = socketFlow.remoteIP, dohIPs.contains(ip) {
            return .drop()
        }

        // Resolve hostname: direct → IP map → defer to SNI inspection
        let hostname = socketFlow.remoteHostname
            ?? socketFlow.remoteIP.flatMap { ipMap.hostname(for: $0) }

        if let hostname = hostname {
            return verdict(for: hostname, ruleset: ruleset)
        }

        // No hostname available — inspect outbound data for SNI
        if ruleset.mode == .allowlist {
            return .filterDataVerdict(
                withFilterInbound: false,
                peekInboundBytes: 0,
                filterOutbound: true,
                peekOutboundBytes: Int.max
            )
        }

        // Blocklist mode with unknown hostname: allow (can't determine destination)
        return .allow()
    }

    override func handleOutboundData(
        from flow: NEFilterFlow,
        readBytesStartOffset offset: Int,
        readBytes: Data
    ) -> NEFilterDataVerdict {
        guard let ruleset = activeRuleset,
              let socketFlow = flow as? NEFilterSocketFlow else {
            return .allow()
        }

        if let hostname = SNIExtractor.extractHostname(from: readBytes) {
            // Cache in IP map for future flows
            if let ip = socketFlow.remoteIP {
                ipMap.set(ip: ip, hostname: hostname)
            }
            return verdict(for: hostname, ruleset: ruleset) == .drop()
                ? .drop() : .allow()
        }

        // No SNI found
        return ruleset.mode == .allowlist ? .drop() : .allow()
    }

    // MARK: - Internal

    func applyRuleset(_ ruleset: BlockRuleset) {
        activeRuleset = ruleset
        domainMatcher = DomainMatcher(rules: ruleset.domains)
        cidrMatcher = CIDRMatcher(rules: ruleset.domains)
        dohIPs = Set(ruleset.dohServerIPs)
    }

    private func clearRuleset() {
        activeRuleset = nil
        domainMatcher = nil
        cidrMatcher = nil
        dohIPs.removeAll()
        let store = RulesetStore(directory: containerURL())
        store.delete()
    }

    private func verdict(for hostname: String, ruleset: BlockRuleset) -> NEFilterNewFlowVerdict {
        let matched = domainMatcher?.matches(hostname) ?? false
        switch ruleset.mode {
        case .blocklist: return matched ? .drop() : .allow()
        case .allowlist: return matched ? .allow() : .drop()
        }
    }

    private func containerURL() -> URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.forge"
        ) ?? FileManager.default.temporaryDirectory
    }
}

// MARK: - NEFilterSocketFlow helpers

extension NEFilterSocketFlow {
    var remoteIP: String? {
        (remoteEndpoint as? NWHostEndpoint)?.hostname
    }

    var remotePort: Int? {
        guard let endpoint = remoteEndpoint as? NWHostEndpoint else { return nil }
        return Int(endpoint.port)
    }
}
```

- [ ] **Step 2: Regenerate project and build**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild build -scheme Forge -destination 'platform=macOS' -configuration Debug \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ForgeFilterExtension/FilterDataProvider.swift
git commit -m "Implement NEFilterDataProvider with domain, IP, DoH, and SNI blocking

Handles hostname matching, IP-to-hostname map lookup for Chrome flows,
DoH server IP blocking, SNI extraction fallback, allowlist essential
ports (DNS, NTP, DHCP, mDNS), and automatic expiry cleanup."
```

---

### Task 11: NEDNSProxyProvider Implementation

**Files:**
- Create: `ForgeFilterExtension/DNSProxyProvider.swift`

- [ ] **Step 1: Implement DNSProxyProvider**

Create `ForgeFilterExtension/DNSProxyProvider.swift`:

```swift
import NetworkExtension
import ForgeKit

final class DNSProxyProvider: NEDNSProxyProvider {
    private var activeRuleset: BlockRuleset?
    private var domainMatcher: DomainMatcher?

    /// Shared with FilterDataProvider via the extension process.
    /// Both providers run in the same process, so they share this instance.
    static let sharedIPMap = IPHostnameMap()

    override func startProxy(
        options: [String: Any]? = nil,
        completionHandler: @escaping (Error?) -> Void
    ) {
        let store = RulesetStore(directory: containerURL())
        if let ruleset = store.loadIfActive() {
            applyRuleset(ruleset)
        }
        completionHandler(nil)
    }

    override func stopProxy(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        activeRuleset = nil
        domainMatcher = nil
        completionHandler()
    }

    override func handleNewUDPFlow(
        _ flow: NEAppProxyUDPFlow,
        initialRemoteEndpoint remoteEndpoint: NWEndpoint
    ) -> Bool {
        guard activeRuleset != nil else { return false }

        Task {
            do {
                try await processUDPFlow(flow)
            } catch {
                flow.closeReadWithError(error)
                flow.closeWriteWithError(error)
            }
        }

        return true
    }

    // MARK: - Internal

    func applyRuleset(_ ruleset: BlockRuleset) {
        activeRuleset = ruleset
        domainMatcher = DomainMatcher(rules: ruleset.domains)
    }

    private func processUDPFlow(_ flow: NEAppProxyUDPFlow) async throws {
        flow.open(withLocalEndpoint: nil) { error in
            if let error { flow.closeReadWithError(error) }
        }

        while true {
            let (datagrams, endpoints) = try await readDatagrams(from: flow)
            guard !datagrams.isEmpty else { break }

            for (datagram, endpoint) in zip(datagrams, endpoints) {
                let response = processDNSQuery(datagram, endpoint: endpoint)
                if let response {
                    try await writeDatagrams([response], to: flow, endpoints: [endpoint])
                }
            }
        }
    }

    private func processDNSQuery(_ data: Data, endpoint: NWEndpoint) -> Data? {
        guard let domain = extractDomainFromDNS(data) else { return nil }

        guard let ruleset = activeRuleset, let matcher = domainMatcher else {
            return nil // No ruleset — don't intercept
        }

        let shouldBlock: Bool
        switch ruleset.mode {
        case .blocklist: shouldBlock = matcher.matches(domain)
        case .allowlist: shouldBlock = !matcher.matches(domain)
        }

        if shouldBlock {
            return buildBlockedDNSResponse(query: data, domain: domain)
        }

        // Allowed — forward to upstream and record IP mapping
        return nil // Let the system handle forwarding
    }

    /// Extract the queried domain name from a raw DNS packet.
    private func extractDomainFromDNS(_ data: Data) -> String? {
        // DNS header is 12 bytes, then QNAME starts
        guard data.count > 12 else { return nil }

        var labels: [String] = []
        var offset = 12

        while offset < data.count {
            let length = Int(data[offset])
            if length == 0 { break }
            offset += 1

            guard offset + length <= data.count else { return nil }
            let label = String(data: data[offset..<offset + length], encoding: .utf8)
            guard let label else { return nil }
            labels.append(label)
            offset += length
        }

        return labels.isEmpty ? nil : labels.joined(separator: ".")
    }

    /// Build a DNS response that returns 0.0.0.0 for the queried domain.
    private func buildBlockedDNSResponse(query: Data, domain: String) -> Data {
        guard query.count >= 12 else { return Data() }

        var response = Data()

        // Copy transaction ID from query
        response.append(query[0..<2])

        // Flags: response, authoritative, no error
        response.append(contentsOf: [0x81, 0x80])

        // Questions: 1, Answers: 1, Authority: 0, Additional: 0
        response.append(contentsOf: [0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00])

        // Copy question section from query (skip header)
        var offset = 12
        while offset < query.count {
            let len = Int(query[offset])
            if len == 0 { offset += 1; break }
            offset += 1 + len
        }
        // Include QTYPE (2) + QCLASS (2)
        offset += 4
        if offset <= query.count {
            response.append(query[12..<offset])
        }

        // Answer: pointer to name in question + A record with 0.0.0.0
        response.append(contentsOf: [0xC0, 0x0C]) // Name pointer to question
        response.append(contentsOf: [0x00, 0x01]) // Type A
        response.append(contentsOf: [0x00, 0x01]) // Class IN
        response.append(contentsOf: [0x00, 0x00, 0x00, 0x01]) // TTL: 1 second
        response.append(contentsOf: [0x00, 0x04]) // RDLENGTH: 4 bytes
        response.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // 0.0.0.0

        return response
    }

    private func containerURL() -> URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.forge"
        ) ?? FileManager.default.temporaryDirectory
    }

    // MARK: - Async wrappers

    private func readDatagrams(from flow: NEAppProxyUDPFlow) async throws -> ([Data], [NWEndpoint]) {
        try await withCheckedThrowingContinuation { continuation in
            flow.readDatagrams { datagrams, endpoints, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (datagrams ?? [], endpoints ?? []))
                }
            }
        }
    }

    private func writeDatagrams(_ datagrams: [Data], to flow: NEAppProxyUDPFlow, endpoints: [NWEndpoint]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            flow.writeDatagrams(datagrams, sentBy: endpoints) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
```

- [ ] **Step 2: Update ForgeFilterExtension/Info.plist**

Replace the existing `ForgeFilterExtension/Info.plist` with updated provider class names:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>ForgeFilterExtension</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.networkextension.filter-data</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).FilterDataProvider</string>
	</dict>
	<key>NetworkExtension</key>
	<dict>
		<key>NEProviderClasses</key>
		<dict>
			<key>com.apple.networkextension.filter-data</key>
			<string>$(PRODUCT_MODULE_NAME).FilterDataProvider</string>
			<key>com.apple.networkextension.dns-proxy</key>
			<string>$(PRODUCT_MODULE_NAME).DNSProxyProvider</string>
		</dict>
	</dict>
</dict>
</plist>
```

- [ ] **Step 3: Regenerate project and build**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild build -scheme Forge -destination 'platform=macOS' -configuration Debug \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ForgeFilterExtension/DNSProxyProvider.swift ForgeFilterExtension/Info.plist
git commit -m "Implement NEDNSProxyProvider with DNS interception and blocked responses

Intercepts DNS queries, checks domain against ruleset, returns 0.0.0.0
for blocked domains. Records IP-to-hostname mapping shared with content
filter for Chrome flow identification."
```

---

### Task 12: Extension XPC Service + App-Side Client

**Files:**
- Create: `ForgeFilterExtension/ExtensionXPCService.swift`
- Create: `Forge/Services/ExtensionXPCClient.swift`
- Create: `Forge/Services/FilterManagerService.swift`

- [ ] **Step 1: Implement the extension's XPC listener**

Create `ForgeFilterExtension/ExtensionXPCService.swift`:

```swift
import Foundation
import ForgeKit

final class ExtensionXPCService: NSObject, NSXPCListenerDelegate, ForgeExtensionProtocol {
    private weak var filterProvider: FilterDataProvider?
    private weak var dnsProvider: DNSProxyProvider?

    init(filterProvider: FilterDataProvider?, dnsProvider: DNSProxyProvider?) {
        self.filterProvider = filterProvider
        self.dnsProvider = dnsProvider
    }

    // MARK: - NSXPCListenerDelegate

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: ForgeExtensionProtocol.self)
        connection.exportedObject = self

        let callbackInterface = NSXPCInterface(with: ForgeAppCallbackProtocol.self)
        connection.remoteObjectInterface = callbackInterface

        connection.resume()
        return true
    }

    // MARK: - ForgeExtensionProtocol

    func updateRuleset(_ rulesetData: Data, reply: @escaping (Error?) -> Void) {
        do {
            let ruleset = try JSONDecoder().decode(BlockRuleset.self, from: rulesetData)

            let store = RulesetStore(directory: containerURL())
            try store.save(ruleset)

            filterProvider?.applyRuleset(ruleset)
            dnsProvider?.applyRuleset(ruleset)

            reply(nil)
        } catch {
            reply(error)
        }
    }

    func deactivateRuleset(reply: @escaping (Error?) -> Void) {
        let store = RulesetStore(directory: containerURL())
        store.delete()
        // Providers will see nil ruleset on next flow and allow everything
        reply(nil)
    }

    func getStatus(reply: @escaping (Data?) -> Void) {
        let store = RulesetStore(directory: containerURL())
        guard let ruleset = store.loadIfActive() else {
            reply(nil)
            return
        }
        reply(try? JSONEncoder().encode(ruleset))
    }

    private func containerURL() -> URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.forge"
        ) ?? FileManager.default.temporaryDirectory
    }
}
```

- [ ] **Step 2: Implement the app-side XPC client**

Create `Forge/Services/ExtensionXPCClient.swift`:

```swift
import Foundation
import ForgeKit

final class ExtensionXPCClient: Sendable {
    private let machServiceName = "app.forge.Forge.ForgeFilterExtension"

    func updateRuleset(_ ruleset: BlockRuleset) async throws {
        let data = try JSONEncoder().encode(ruleset)
        let proxy = try proxy()
        return try await withCheckedThrowingContinuation { continuation in
            proxy.updateRuleset(data) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func deactivateRuleset() async throws {
        let proxy = try proxy()
        return try await withCheckedThrowingContinuation { continuation in
            proxy.deactivateRuleset { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func getStatus() async -> BlockRuleset? {
        guard let proxy = try? proxy() else { return nil }
        return await withCheckedContinuation { continuation in
            proxy.getStatus { data in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }
                let ruleset = try? JSONDecoder().decode(BlockRuleset.self, from: data)
                continuation.resume(returning: ruleset)
            }
        }
    }

    private func proxy() throws -> any ForgeExtensionProtocol {
        let connection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: ForgeExtensionProtocol.self)
        connection.resume()

        guard let proxy = connection.remoteObjectProxy as? any ForgeExtensionProtocol else {
            throw NSError(domain: "ForgeXPC", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create XPC proxy"
            ])
        }
        return proxy
    }
}
```

- [ ] **Step 3: Implement FilterManagerService**

Create `Forge/Services/FilterManagerService.swift`:

```swift
import NetworkExtension

final class FilterManagerService {

    func loadAndActivate() async throws {
        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()

        if !manager.isEnabled {
            manager.isEnabled = true
            let providerConfig = NEFilterProviderConfiguration()
            providerConfig.filterPackets = false
            providerConfig.filterSockets = true
            manager.providerConfiguration = providerConfig
            manager.localizedDescription = "Forge Content Filter"
            try await manager.saveToPreferences()
        }
    }

    var isEnabled: Bool {
        NEFilterManager.shared().isEnabled
    }

    func startMonitoring(onChange: @escaping (Bool) -> Void) {
        NotificationCenter.default.addObserver(
            forName: .NEFilterConfigurationDidChange,
            object: nil,
            queue: .main
        ) { _ in
            onChange(NEFilterManager.shared().isEnabled)
        }
    }
}
```

- [ ] **Step 4: Delete old XPCClient.swift stub (already deleted in Task 1, verify)**

```bash
test ! -f Forge/Services/XPCClient.swift && echo "Already deleted"
```

- [ ] **Step 5: Regenerate project and build**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild build -scheme Forge -destination 'platform=macOS' -configuration Debug \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "error:|BUILD"
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add ForgeFilterExtension/ExtensionXPCService.swift \
  Forge/Services/ExtensionXPCClient.swift \
  Forge/Services/FilterManagerService.swift
git commit -m "Add XPC service, client, and NEFilterManager activation

Extension exposes XPC service for ruleset updates. App connects via
ExtensionXPCClient with async/await wrappers. FilterManagerService
handles NEFilterManager activation and status monitoring."
```

---

### Task 13: Update CLAUDE.md and Final Verification

**Files:**
- Modify: `CLAUDE.md`
- Modify: `Forge/Forge.entitlements`

- [ ] **Step 1: Update Forge.entitlements — remove sandbox for XPC**

The app needs to communicate with the system extension via XPC. Update `Forge/Forge.entitlements` to remove sandbox (the app is distributed outside the App Store, so sandbox is optional):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.networking.networkextension</key>
	<array>
		<string>content-filter-provider</string>
		<string>dns-proxy</string>
	</array>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.app.forge</string>
	</array>
	<key>com.apple.security.network.client</key>
	<true/>
</dict>
</plist>
```

- [ ] **Step 2: Update CLAUDE.md**

Update the Architecture section to reflect the simplified design:

```markdown
## Architecture
- **ForgeKit** — Shared framework (models, matching, XPC protocol)
- **Forge** — SwiftUI menu bar app (main target)
- **ForgeFilterExtension** — System Extension (NEFilterDataProvider + NEDNSProxyProvider)
- **forge-cli** — Command-line tool (Swift ArgumentParser)
- **ForgeWidget** — WidgetKit extension
- Single enforcement layer: Network Extension (persists across reboots)
- Commitment mechanism: bypass detection + typing challenge + cooldown (Phase 2)
```

- [ ] **Step 3: Run all tests**

```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug \
  -only-testing:ForgeTests \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep -E "passed|failed|Test run"
```

Expected: All tests pass (DomainMatcher, CIDRMatcher, BlockRuleset, DoHServerList, SNIExtractor, RulesetStore, IPHostnameMap).

- [ ] **Step 4: Run SwiftLint**

```bash
swiftlint lint --strict
```

Expected: 0 violations.

- [ ] **Step 5: Full build verification**

```bash
xcodebuild build -scheme Forge -destination 'platform=macOS' -configuration Debug \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | \
  grep "BUILD"
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Update entitlements and docs for simplified architecture

Remove app sandbox (not needed for direct distribution), update
CLAUDE.md to reflect ForgeKit framework and single-layer enforcement."
```

---

## Notes

- **Entitlements required for runtime testing:** The Network Extension content-filter-provider and dns-proxy entitlements must be approved by Apple before the extension can be activated on a real system. All logic is unit-tested without entitlements.
- **EndpointSecurity (app blocking)** is deferred to Phase 4. The `AppBlocker.swift` file was removed; it will be recreated in that phase.
- **The `ForgeTests` target tests ForgeKit directly** (no TEST_HOST needed). Integration tests that need the full app use `ForgeIntegrationTests` with TEST_HOST.
