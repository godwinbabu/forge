# Block Engine + Basic UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A user can start, extend, and complete a block through a functional SwiftUI interface. The BlockEngine orchestrates the extension, SwiftData persists sessions, and the menu bar shows live status.

**Architecture:** `BlockEngine` is the central orchestrator — it builds rulesets from profiles, sends them to the extension via `ExtensionXPCClient`, records sessions in SwiftData, and manages the block lifecycle timer. `AppState` is the observable source of truth for all UI. The menu bar and dashboard both read from `AppState`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, ForgeKit, LocalAuthentication (Touch ID)

**Spec:** `docs/superpowers/specs/2026-03-27-simplified-architecture-design.md`
**Design reference:** `docs/design-spec.md` Sections 8 and 9

---

## File Structure

### Files to create

```
Forge/Services/BlockEngine.swift          # Rewrite — orchestrates start/stop/extend
Forge/Services/PresetProfileLoader.swift  # Load preset profiles from JSON

Forge/App/AppState.swift                  # Rewrite — full observable state
Forge/App/ForgeApp.swift                  # Rewrite — SwiftData container + scenes
Forge/App/ContentView.swift              # Rewrite — NavigationSplitView with routing

Forge/Views/Dashboard/DashboardView.swift       # Rewrite — ready vs active states
Forge/Views/Dashboard/ActiveBlockView.swift     # Rewrite — countdown + controls
Forge/Views/Dashboard/ProfileCardView.swift     # Rewrite — tap-to-start cards
Forge/Views/Dashboard/DurationPickerView.swift  # New — slider for block duration
Forge/Views/Shared/CountdownTimerView.swift     # Rewrite — live updating timer

Forge/Views/Profiles/ProfileListView.swift      # Rewrite — list of profiles
Forge/Views/Settings/SettingsView.swift         # Rewrite — placeholder with version

Forge/App/MenuBarView.swift              # Rewrite — status + quick actions

ForgeTests/BlockEngineTests.swift        # BlockEngine logic tests
ForgeTests/PresetProfileLoaderTests.swift # Preset loading tests
```

### Files to modify

```
Forge/Models/BlockProfile.swift          # Add id field, match design spec
Forge/Models/BlockSession.swift          # Add actualEndDate, wasExtended fields
Forge/App/AppState.swift                 # Full rewrite with block state
```

---

### Task 1: Update SwiftData Models

**Files:**
- Modify: `Forge/Models/BlockProfile.swift`
- Modify: `Forge/Models/BlockSession.swift`
- Modify: `Forge/Models/BlockSchedule.swift`

- [ ] **Step 1: Update BlockProfile to match design spec**

Rewrite `Forge/Models/BlockProfile.swift`:
```swift
import Foundation
import SwiftData

@Model
final class BlockProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var isBlocklist: Bool
    var domains: [String]
    var appBundleIDs: [String]
    var expandSubdomains: Bool
    var allowLocalNetwork: Bool
    var clearBrowserCaches: Bool
    var isPinned: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "shield.fill",
        colorHex: String = "#007AFF",
        isBlocklist: Bool = true,
        domains: [String] = [],
        appBundleIDs: [String] = [],
        expandSubdomains: Bool = true,
        allowLocalNetwork: Bool = true,
        clearBrowserCaches: Bool = false,
        isPinned: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isBlocklist = isBlocklist
        self.domains = domains
        self.appBundleIDs = appBundleIDs
        self.expandSubdomains = expandSubdomains
        self.allowLocalNetwork = allowLocalNetwork
        self.clearBrowserCaches = clearBrowserCaches
        self.isPinned = isPinned
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

- [ ] **Step 2: Update BlockSession with additional fields**

Rewrite `Forge/Models/BlockSession.swift`:
```swift
import Foundation
import SwiftData

@Model
final class BlockSession {
    @Attribute(.unique) var id: UUID
    var profileID: UUID?
    var profileName: String
    var startDate: Date
    var endDate: Date
    var actualEndDate: Date?
    var domains: [String]
    var isBlocklist: Bool
    var blockedAttemptCount: Int
    var wasExtended: Bool
    var trigger: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        profileID: UUID? = nil,
        profileName: String,
        startDate: Date,
        endDate: Date,
        domains: [String] = [],
        isBlocklist: Bool = true,
        blockedAttemptCount: Int = 0,
        wasExtended: Bool = false,
        trigger: String = "manual"
    ) {
        self.id = id
        self.profileID = profileID
        self.profileName = profileName
        self.startDate = startDate
        self.endDate = endDate
        self.domains = domains
        self.isBlocklist = isBlocklist
        self.blockedAttemptCount = blockedAttemptCount
        self.wasExtended = wasExtended
        self.trigger = trigger
        self.createdAt = .now
    }
}
```

- [ ] **Step 3: Regenerate and build**
```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild build -scheme Forge -destination 'platform=macOS' -configuration Debug CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 4: Commit**
```bash
git add Forge/Models/
git commit -m "Update SwiftData models with id fields, session tracking, pinned profiles"
```

---

### Task 2: AppState + BlockEngine (TDD)

**Files:**
- Rewrite: `Forge/App/AppState.swift`
- Rewrite: `Forge/Services/BlockEngine.swift`
- Create: `ForgeTests/BlockEngineTests.swift`

- [ ] **Step 1: Write failing tests for BlockEngine**

Create `ForgeTests/BlockEngineTests.swift`:
```swift
import Testing
import Foundation
@testable import ForgeKit

@Suite("BlockEngine Tests")
struct BlockEngineTests {

    @Test func buildRulesetFromProfile() {
        let domains = ["reddit.com", "twitter.com"]
        let ruleset = BlockEngineHelper.buildRuleset(
            domains: domains,
            appBundleIDs: [],
            isBlocklist: true,
            expandSubdomains: true,
            allowLocalNetwork: true,
            durationSeconds: 3600,
            dohServerIPs: ["1.1.1.1"]
        )

        #expect(ruleset.mode == .blocklist)
        #expect(ruleset.allowLocalNetwork == true)
        #expect(ruleset.expandCommonSubdomains == true)
        #expect(ruleset.dohServerIPs == ["1.1.1.1"])
        // With expansion: reddit.com + www.reddit.com + m.reddit.com + mobile.reddit.com + api.reddit.com
        // + twitter.com + www.twitter.com + m.twitter.com + mobile.twitter.com + api.twitter.com
        #expect(ruleset.domains.count == 10)
    }

    @Test func buildRulesetSetsCorrectEndDate() {
        let before = Date()
        let ruleset = BlockEngineHelper.buildRuleset(
            domains: ["test.com"],
            appBundleIDs: [],
            isBlocklist: true,
            expandSubdomains: false,
            allowLocalNetwork: true,
            durationSeconds: 1800,
            dohServerIPs: []
        )
        let after = Date()

        #expect(ruleset.endDate >= before.addingTimeInterval(1800))
        #expect(ruleset.endDate <= after.addingTimeInterval(1800))
    }

    @Test func buildRulesetAllowlistMode() {
        let ruleset = BlockEngineHelper.buildRuleset(
            domains: ["allowed.com"],
            appBundleIDs: [],
            isBlocklist: false,
            expandSubdomains: false,
            allowLocalNetwork: true,
            durationSeconds: 3600,
            dohServerIPs: []
        )
        #expect(ruleset.mode == .allowlist)
    }

    @Test func buildRulesetConvertsDomainsToExactRules() {
        let ruleset = BlockEngineHelper.buildRuleset(
            domains: ["reddit.com"],
            appBundleIDs: [],
            isBlocklist: true,
            expandSubdomains: false,
            allowLocalNetwork: true,
            durationSeconds: 3600,
            dohServerIPs: []
        )
        #expect(ruleset.domains == [.exact("reddit.com")])
    }
}
```

- [ ] **Step 2: Create BlockEngineHelper in ForgeKit**

Since BlockEngine itself depends on SwiftData and XPC (not testable in ForgeKit tests), extract the pure logic into a testable helper in ForgeKit.

Create `ForgeKit/BlockEngineHelper.swift`:
```swift
import Foundation

public enum BlockEngineHelper {
    public static func buildRuleset(
        domains: [String],
        appBundleIDs: [String],
        isBlocklist: Bool,
        expandSubdomains: Bool,
        allowLocalNetwork: Bool,
        durationSeconds: TimeInterval,
        dohServerIPs: [String]
    ) -> BlockRuleset {
        let domainRules = domains.map { DomainRule.exact($0) }

        return BlockRuleset(
            id: UUID(),
            mode: isBlocklist ? .blocklist : .allowlist,
            domains: domainRules,
            appBundleIDs: appBundleIDs,
            dohServerIPs: dohServerIPs,
            allowLocalNetwork: allowLocalNetwork,
            expandCommonSubdomains: expandSubdomains,
            startDate: .now,
            endDate: .now.addingTimeInterval(durationSeconds)
        )
    }
}
```

- [ ] **Step 3: Run tests, verify pass**

- [ ] **Step 4: Rewrite AppState**

Rewrite `Forge/App/AppState.swift`:
```swift
import SwiftUI
import ForgeKit

@Observable
final class AppState {
    // Block state
    var isBlockActive = false
    var blockEndDate: Date?
    var activeProfileID: UUID?
    var activeProfileName: String?
    var activeProfileIcon: String?
    var activeProfileColor: String?
    var blockedAttemptCount: Int = 0

    // UI state
    var selectedSidebarItem: SidebarItem = .dashboard
    var showingDurationPicker = false
    var selectedDuration: TimeInterval = 3600 // 1 hour default

    func activateBlock(
        profileID: UUID,
        profileName: String,
        profileIcon: String,
        profileColor: String,
        endDate: Date
    ) {
        isBlockActive = true
        blockEndDate = endDate
        activeProfileID = profileID
        activeProfileName = profileName
        activeProfileIcon = profileIcon
        activeProfileColor = profileColor
        blockedAttemptCount = 0
    }

    func deactivateBlock() {
        isBlockActive = false
        blockEndDate = nil
        activeProfileID = nil
        activeProfileName = nil
        activeProfileIcon = nil
        activeProfileColor = nil
        blockedAttemptCount = 0
    }

    func extendBlock(by seconds: TimeInterval) {
        guard let current = blockEndDate else { return }
        blockEndDate = current.addingTimeInterval(seconds)
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case profiles = "Profiles"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.bottom.50percent"
        case .profiles: "person.crop.rectangle.stack"
        case .settings: "gear"
        }
    }
}
```

- [ ] **Step 5: Rewrite BlockEngine**

Rewrite `Forge/Services/BlockEngine.swift`:
```swift
import Foundation
import SwiftData
import ForgeKit

@Observable
final class BlockEngine {
    private let xpcClient = ExtensionXPCClient()
    private var expiryTimer: Timer?

    func startBlock(
        profile: BlockProfile,
        duration: TimeInterval,
        dohServerIPs: [String],
        appState: AppState,
        modelContext: ModelContext
    ) async throws {
        let ruleset = BlockEngineHelper.buildRuleset(
            domains: profile.domains,
            appBundleIDs: profile.appBundleIDs,
            isBlocklist: profile.isBlocklist,
            expandSubdomains: profile.expandSubdomains,
            allowLocalNetwork: profile.allowLocalNetwork,
            durationSeconds: duration,
            dohServerIPs: dohServerIPs
        )

        try await xpcClient.updateRuleset(ruleset)

        let session = BlockSession(
            profileID: profile.id,
            profileName: profile.name,
            startDate: ruleset.startDate,
            endDate: ruleset.endDate,
            domains: profile.domains,
            isBlocklist: profile.isBlocklist,
            trigger: "manual"
        )
        modelContext.insert(session)
        try modelContext.save()

        await MainActor.run {
            appState.activateBlock(
                profileID: profile.id,
                profileName: profile.name,
                profileIcon: profile.iconName,
                profileColor: profile.colorHex,
                endDate: ruleset.endDate
            )
        }

        scheduleExpiryTimer(endDate: ruleset.endDate, appState: appState)
    }

    func extendBlock(
        by seconds: TimeInterval,
        appState: AppState
    ) async throws {
        guard let currentEnd = appState.blockEndDate else { return }
        let newEnd = currentEnd.addingTimeInterval(seconds)

        // Get current status and update
        if let current = await xpcClient.getStatus() {
            let extended = BlockRuleset(
                id: current.id,
                mode: current.mode,
                domains: current.domains,
                appBundleIDs: current.appBundleIDs,
                dohServerIPs: current.dohServerIPs,
                allowLocalNetwork: current.allowLocalNetwork,
                expandCommonSubdomains: false, // Already expanded
                startDate: current.startDate,
                endDate: newEnd
            )
            try await xpcClient.updateRuleset(extended)
        }

        await MainActor.run {
            appState.extendBlock(by: seconds)
        }

        scheduleExpiryTimer(endDate: newEnd, appState: appState)
    }

    func stopBlock(appState: AppState) async {
        expiryTimer?.invalidate()
        expiryTimer = nil

        try? await xpcClient.deactivateRuleset()

        await MainActor.run {
            appState.deactivateBlock()
        }
    }

    func checkExistingBlock(appState: AppState) async {
        guard let ruleset = await xpcClient.getStatus() else { return }
        if ruleset.isExpired { return }

        await MainActor.run {
            appState.activateBlock(
                profileID: UUID(), // Unknown from extension
                profileName: "Active Block",
                profileIcon: "flame.fill",
                profileColor: "#FF9500",
                endDate: ruleset.endDate
            )
        }

        scheduleExpiryTimer(endDate: ruleset.endDate, appState: appState)
    }

    private func scheduleExpiryTimer(endDate: Date, appState: AppState) {
        expiryTimer?.invalidate()
        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else {
            Task { await stopBlock(appState: appState) }
            return
        }

        expiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { await self?.stopBlock(appState: appState) }
        }
    }
}
```

- [ ] **Step 6: Regenerate, build, run tests**
- [ ] **Step 7: Commit**
```bash
git add ForgeKit/BlockEngineHelper.swift Forge/App/AppState.swift Forge/Services/BlockEngine.swift ForgeTests/BlockEngineTests.swift
git commit -m "Add BlockEngine orchestrator with AppState and TDD-tested helper

BlockEngine manages block lifecycle: start, extend, stop, expiry.
AppState is the observable source of truth for all UI. BlockEngineHelper
extracts testable ruleset-building logic into ForgeKit."
```

---

### Task 3: Preset Profile Loader (TDD)

**Files:**
- Create: `Forge/Services/PresetProfileLoader.swift`
- Create: `ForgeTests/PresetProfileLoaderTests.swift`

- [ ] **Step 1: Write failing test**

Create `ForgeTests/PresetProfileLoaderTests.swift`:
```swift
import Testing
import Foundation

@Suite("PresetProfileLoader Tests")
struct PresetProfileLoaderTests {
    @Test func loadsPresetsFromJSON() throws {
        let json = """
        [{"name":"Social Media","iconName":"bubble.left.and.bubble.right.fill","colorHex":"#FF3B30","isBlocklist":true,"domains":["facebook.com","instagram.com"],"appBundleIDs":[],"expandSubdomains":true,"allowLocalNetwork":true,"clearBrowserCaches":false}]
        """.data(using: .utf8)!

        let presets = try PresetProfileLoader.load(from: json)
        #expect(presets.count == 1)
        #expect(presets[0].name == "Social Media")
        #expect(presets[0].domains == ["facebook.com", "instagram.com"])
    }

    @Test func emptyArrayProducesNoPresets() throws {
        let json = "[]".data(using: .utf8)!
        let presets = try PresetProfileLoader.load(from: json)
        #expect(presets.isEmpty)
    }
}
```

- [ ] **Step 2: Implement PresetProfileLoader**

Create `Forge/Services/PresetProfileLoader.swift`:
```swift
import Foundation

struct PresetProfileData: Codable {
    let name: String
    let iconName: String
    let colorHex: String
    let isBlocklist: Bool
    let domains: [String]
    let appBundleIDs: [String]
    let expandSubdomains: Bool
    let allowLocalNetwork: Bool
    let clearBrowserCaches: Bool
}

enum PresetProfileLoader {
    static func load(from data: Data) throws -> [PresetProfileData] {
        try JSONDecoder().decode([PresetProfileData].self, from: data)
    }

    static func loadBundled() -> [PresetProfileData] {
        guard let url = Bundle.main.url(forResource: "PresetProfiles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let presets = try? load(from: data) else {
            return []
        }
        return presets
    }
}
```

- [ ] **Step 3: Run tests, lint, commit**
```bash
git add Forge/Services/PresetProfileLoader.swift ForgeTests/PresetProfileLoaderTests.swift
git commit -m "Add PresetProfileLoader for bundled profile templates"
```

---

### Task 4: ForgeApp Entry Point + SwiftData Container

**Files:**
- Rewrite: `Forge/App/ForgeApp.swift`

- [ ] **Step 1: Rewrite ForgeApp with SwiftData and state injection**

```swift
import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    @State private var appState = AppState()
    @State private var blockEngine = BlockEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(blockEngine)
        }
        .modelContainer(for: [BlockProfile.self, BlockSession.self, BlockSchedule.self])

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .environment(blockEngine)
        } label: {
            Label("Forge", systemImage: appState.isBlockActive ? "flame.fill" : "flame")
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: Build, commit**
```bash
git add Forge/App/ForgeApp.swift
git commit -m "Wire ForgeApp with SwiftData container and environment injection"
```

---

### Task 5: Dashboard UI (Ready + Active States)

**Files:**
- Rewrite: `Forge/App/ContentView.swift`
- Rewrite: `Forge/Views/Dashboard/DashboardView.swift`
- Rewrite: `Forge/Views/Dashboard/ActiveBlockView.swift`
- Rewrite: `Forge/Views/Dashboard/ProfileCardView.swift`
- Create: `Forge/Views/Dashboard/DurationPickerView.swift`
- Rewrite: `Forge/Views/Shared/CountdownTimerView.swift`

- [ ] **Step 1: Rewrite ContentView with NavigationSplitView**

```swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $state.selectedSidebarItem) { item in
                Label(item.rawValue, systemImage: item.icon)
            }
            .navigationTitle("Forge")
        } detail: {
            switch appState.selectedSidebarItem {
            case .dashboard:
                DashboardView()
            case .profiles:
                ProfileListView()
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
```

- [ ] **Step 2: Rewrite DashboardView**

```swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isBlockActive {
            ActiveBlockView()
        } else {
            ReadyView()
        }
    }
}

struct ReadyView: View {
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BlockProfile.sortOrder) private var profiles: [BlockProfile]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Ready to focus")
                    .font(.largeTitle.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if profiles.isEmpty {
                    ContentUnavailableView(
                        "No Profiles",
                        systemImage: "plus.circle",
                        description: Text("Create a profile to get started")
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                        ForEach(profiles) { profile in
                            ProfileCardView(profile: profile)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
```

- [ ] **Step 3: Rewrite ActiveBlockView**

```swift
import SwiftUI

struct ActiveBlockView: View {
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @State private var showingExtend = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if let icon = appState.activeProfileIcon {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
            }

            if let name = appState.activeProfileName {
                Text(name)
                    .font(.title2.weight(.medium))
            }

            if let endDate = appState.blockEndDate {
                CountdownTimerView(endDate: endDate)
            }

            HStack(spacing: 16) {
                Button("Extend 30 min") {
                    Task {
                        try? await blockEngine.extendBlock(
                            by: 1800,
                            appState: appState
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Text("\(appState.blockedAttemptCount) blocked attempts")
                .foregroundStyle(.secondary)
                .font(.callout)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 4: Rewrite ProfileCardView**

```swift
import SwiftUI

struct ProfileCardView: View {
    let profile: BlockProfile
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @Environment(\.modelContext) private var modelContext
    @State private var showingDuration = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: profile.iconName)
                    .font(.title2)
                    .foregroundStyle(Color(hex: profile.colorHex) ?? .accentColor)
                Spacer()
                Text(profile.isBlocklist ? "Blocklist" : "Allowlist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(profile.name)
                .font(.headline)

            Text("\(profile.domains.count) sites")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture { showingDuration = true }
        .sheet(isPresented: $showingDuration) {
            DurationPickerView(profile: profile)
        }
    }
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let int = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}
```

- [ ] **Step 5: Create DurationPickerView**

Create `Forge/Views/Dashboard/DurationPickerView.swift`:
```swift
import SwiftUI

struct DurationPickerView: View {
    let profile: BlockProfile
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var durationMinutes: Double = 60

    var body: some View {
        VStack(spacing: 24) {
            Text("Start \(profile.name)")
                .font(.title2.weight(.semibold))

            VStack(spacing: 8) {
                Text(formattedDuration)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())

                Slider(value: $durationMinutes, in: 15...480, step: 15)
                    .padding(.horizontal)

                HStack {
                    Text("15 min")
                    Spacer()
                    Text("8 hours")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }

            Button("Start Block") {
                Task {
                    try? await blockEngine.startBlock(
                        profile: profile,
                        duration: durationMinutes * 60,
                        dohServerIPs: [],
                        appState: appState,
                        modelContext: modelContext
                    )
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 360)
    }

    private var formattedDuration: String {
        let hours = Int(durationMinutes) / 60
        let mins = Int(durationMinutes) % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }
}
```

- [ ] **Step 6: Rewrite CountdownTimerView**

```swift
import SwiftUI

struct CountdownTimerView: View {
    let endDate: Date
    @State private var timeRemaining: TimeInterval = 0

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 64, weight: .bold, design: .monospaced))
            .onAppear { updateTime() }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                updateTime()
            }
    }

    private func updateTime() {
        timeRemaining = max(0, endDate.timeIntervalSinceNow)
    }

    private var formattedTime: String {
        let total = Int(timeRemaining)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

- [ ] **Step 7: Build, commit**
```bash
git add Forge/App/ContentView.swift Forge/Views/Dashboard/ Forge/Views/Shared/CountdownTimerView.swift
git commit -m "Implement dashboard with ready/active states and duration picker

NavigationSplitView with sidebar, profile cards grid, duration slider
sheet, active block countdown, extend button. CountdownTimerView updates
every second with formatted HH:MM:SS display."
```

---

### Task 6: Menu Bar View

**Files:**
- Rewrite: `Forge/App/MenuBarView.swift`

- [ ] **Step 1: Rewrite MenuBarView**

```swift
import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine

    var body: some View {
        VStack(spacing: 0) {
            if appState.isBlockActive {
                activeContent
            } else {
                readyContent
            }

            Divider()

            Button("Open Forge...") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Button("Quit Forge") {
                if !appState.isBlockActive {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .disabled(appState.isBlockActive)
        }
        .frame(width: 280)
    }

    private var activeContent: some View {
        VStack(spacing: 12) {
            HStack {
                if let icon = appState.activeProfileIcon {
                    Image(systemName: icon)
                        .foregroundStyle(.tint)
                }
                Text(appState.activeProfileName ?? "Active Block")
                    .font(.headline)
                Spacer()
            }

            if let endDate = appState.blockEndDate {
                CountdownTimerView(endDate: endDate)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
            }

            Text("\(appState.blockedAttemptCount) blocked")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var readyContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Ready to focus")
                .font(.headline)
            Text("Open Forge to start a block")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
```

- [ ] **Step 2: Build, commit**
```bash
git add Forge/App/MenuBarView.swift
git commit -m "Implement menu bar with active block status and quick actions

Shows countdown timer and profile info when block active, ready state
when idle. Quit disabled during active block."
```

---

### Task 7: Profile List + Settings Placeholders + Seed Presets

**Files:**
- Rewrite: `Forge/Views/Profiles/ProfileListView.swift`
- Rewrite: `Forge/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Rewrite ProfileListView**

```swift
import SwiftUI
import SwiftData

struct ProfileListView: View {
    @Query(sort: \BlockProfile.sortOrder) private var profiles: [BlockProfile]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(profiles) { profile in
                HStack(spacing: 12) {
                    Image(systemName: profile.iconName)
                        .font(.title2)
                        .foregroundStyle(Color(hex: profile.colorHex) ?? .accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading) {
                        Text(profile.name)
                            .font(.headline)
                        Text("\(profile.domains.count) sites · \(profile.isBlocklist ? "Blocklist" : "Allowlist")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteProfiles)
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem {
                Button("Seed Presets", systemImage: "arrow.down.circle") {
                    seedPresetProfiles()
                }
            }
        }
        .overlay {
            if profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "shield.slash",
                    description: Text("Tap 'Seed Presets' to load built-in profiles")
                )
            }
        }
    }

    private func deleteProfiles(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(profiles[index])
        }
    }

    private func seedPresetProfiles() {
        let presets = PresetProfileLoader.loadBundled()
        for (index, preset) in presets.enumerated() {
            let profile = BlockProfile(
                name: preset.name,
                iconName: preset.iconName,
                colorHex: preset.colorHex,
                isBlocklist: preset.isBlocklist,
                domains: preset.domains,
                appBundleIDs: preset.appBundleIDs,
                expandSubdomains: preset.expandSubdomains,
                allowLocalNetwork: preset.allowLocalNetwork,
                clearBrowserCaches: preset.clearBrowserCaches,
                sortOrder: index
            )
            modelContext.insert(profile)
        }
    }
}
```

- [ ] **Step 2: Rewrite SettingsView**

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Build", value: "1")
            }

            Section("Blocking") {
                Text("Extension and notification settings coming in Phase 5")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
```

- [ ] **Step 3: Build, commit**
```bash
git add Forge/Views/Profiles/ProfileListView.swift Forge/Views/Settings/SettingsView.swift
git commit -m "Implement profile list with preset seeding and settings placeholder

Profile list shows icon, name, site count. Seed Presets button loads
built-in profiles from PresetProfiles.json."
```

---

### Task 8: Wire App Group UserDefaults for Widget + Final Polish

**Files:**
- Modify: `Forge/Services/BlockEngine.swift` — write status to App Group UserDefaults
- Clean up unused view stubs

- [ ] **Step 1: Add App Group UserDefaults writing to BlockEngine**

Add to BlockEngine's `startBlock` and `stopBlock` methods, after updating appState:
```swift
private func writeSharedStatus(appState: AppState) {
    guard let defaults = UserDefaults(suiteName: "group.app.forge") else { return }
    defaults.set(appState.isBlockActive, forKey: "isBlockActive")
    defaults.set(appState.blockEndDate, forKey: "blockEndDate")
    defaults.set(appState.activeProfileName, forKey: "activeProfileName")
    defaults.set(appState.blockedAttemptCount, forKey: "blockedAttemptCount")
}
```

Call `writeSharedStatus(appState:)` at end of `startBlock`, `extendBlock`, and `stopBlock`.

- [ ] **Step 2: Delete unused Phase 0 view stubs that are no longer needed**

Delete these files that were Phase 0 placeholders and aren't used by any view:
- `Forge/Views/Shared/ProgressBarView.swift`
- `Forge/Views/Insights/FocusTimeChart.swift`
- `Forge/Views/Insights/BlockedAttemptsChart.swift`
- `Forge/Views/Insights/InsightsView.swift`
- `Forge/Views/Onboarding/OnboardingFlow.swift`
- `Forge/Views/Schedules/ScheduleListView.swift`
- `Forge/Views/Schedules/ScheduleEditorView.swift`
- `Forge/Views/Profiles/ProfileEditorView.swift`
- `Forge/Views/Profiles/DomainListView.swift`
- `Forge/App/CommandPalette.swift`

These will be recreated in their respective phases with real implementations.

- [ ] **Step 3: Run full build, all tests, lint**
```bash
rm -rf Forge.xcodeproj && xcodegen generate
xcodebuild build -scheme Forge -destination 'platform=macOS' -configuration Debug CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
xcodebuild test -scheme Forge -destination 'platform=macOS' -configuration Debug -only-testing:ForgeTests CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
swiftlint lint --strict
```

- [ ] **Step 4: Commit**
```bash
git add -A
git commit -m "Add App Group status sharing and clean up unused Phase 0 stubs

BlockEngine writes block status to shared UserDefaults for widget.
Removed placeholder views that will be rebuilt in later phases."
```

---

## Notes

- **Touch ID authentication** is deferred — the design spec calls for it on block start, but it requires LocalAuthentication framework integration that's better added after the basic flow works end-to-end. It will be added in Phase 7 (Polish).
- **The app won't actually block websites yet** without Apple NE entitlement approval. But the full UI flow (pick profile → set duration → start → countdown → expiry) works, and the XPC calls to the extension are wired up.
- **Preset profiles** are loaded from `PresetProfiles.json` via the "Seed Presets" button. Auto-seeding on first launch is deferred to Phase 7 (Onboarding).
