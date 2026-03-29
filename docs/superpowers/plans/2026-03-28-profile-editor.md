# Profile Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Full-featured profile editor with domain list management, app picker, icon/color selection, and JSON import/export.

**Architecture:** `ProfileDraft` struct holds editor state without touching SwiftData. `DomainValidator` and `ProfileSerializer` provide testable logic in ForgeKit. SwiftUI views handle the editor form, domain list, app picker, and icon grid. `ProfileListView` is updated with toolbar buttons and sheet presentation.

**Tech Stack:** SwiftUI, SwiftData, ForgeKit, Swift Testing, NSSavePanel/NSOpenPanel

---

## File Structure

| File | Responsibility |
|------|---------------|
| `ForgeKit/ProfileDraft.swift` (create) | Editor state struct with defaults |
| `ForgeKit/DomainValidator.swift` (create) | Domain validation and normalization |
| `ForgeKit/ProfileSerializer.swift` (create) | Encode/decode ProfileDraft ↔ JSON |
| `Forge/Services/InstalledAppScanner.swift` (create) | Scan /Applications for .app bundles |
| `Forge/Views/Profiles/ProfileEditorView.swift` (create) | Main editor form |
| `Forge/Views/Profiles/DomainListEditor.swift` (create) | Domain list add/remove/paste UI |
| `Forge/Views/Profiles/AppPickerView.swift` (create) | Installed app browser with selection |
| `Forge/Views/Profiles/IconPickerView.swift` (create) | Curated SF Symbol grid |
| `Forge/Views/Profiles/ProfileListView.swift` (modify) | Toolbar, sheets, delete confirm, export |
| `ForgeTests/ProfileDraftTests.swift` (create) | Draft defaults tests |
| `ForgeTests/DomainValidatorTests.swift` (create) | Validation logic tests |
| `ForgeTests/ProfileSerializerTests.swift` (create) | Encode/decode roundtrip tests |

---

### Task 1: ProfileDraft + DomainValidator (TDD)

**Files:**
- Create: `ForgeTests/ProfileDraftTests.swift`
- Create: `ForgeTests/DomainValidatorTests.swift`
- Create: `ForgeKit/ProfileDraft.swift`
- Create: `ForgeKit/DomainValidator.swift`

- [ ] **Step 1: Write failing tests for ProfileDraft**

```swift
// ForgeTests/ProfileDraftTests.swift
import Testing
@testable import ForgeKit

@Suite("ProfileDraft Tests")
struct ProfileDraftTests {

    @Test func defaultsHaveExpectedValues() {
        let draft = ProfileDraft.defaults
        #expect(draft.name == "")
        #expect(draft.iconName == "shield.fill")
        #expect(draft.colorHex == "#007AFF")
        #expect(draft.isBlocklist == true)
        #expect(draft.domains.isEmpty)
        #expect(draft.appBundleIDs.isEmpty)
        #expect(draft.expandSubdomains == true)
        #expect(draft.allowLocalNetwork == true)
        #expect(draft.clearBrowserCaches == false)
    }

    @Test func initWithAllFields() {
        let draft = ProfileDraft(
            name: "Work",
            iconName: "briefcase.fill",
            colorHex: "#FF0000",
            isBlocklist: false,
            domains: ["reddit.com"],
            appBundleIDs: ["com.valvesoftware.steam"],
            expandSubdomains: false,
            allowLocalNetwork: false,
            clearBrowserCaches: true
        )
        #expect(draft.name == "Work")
        #expect(draft.iconName == "briefcase.fill")
        #expect(draft.colorHex == "#FF0000")
        #expect(draft.isBlocklist == false)
        #expect(draft.domains == ["reddit.com"])
        #expect(draft.appBundleIDs == ["com.valvesoftware.steam"])
        #expect(draft.expandSubdomains == false)
        #expect(draft.allowLocalNetwork == false)
        #expect(draft.clearBrowserCaches == true)
    }
}
```

- [ ] **Step 2: Write failing tests for DomainValidator**

```swift
// ForgeTests/DomainValidatorTests.swift
import Testing
@testable import ForgeKit

@Suite("DomainValidator Tests")
struct DomainValidatorTests {

    @Test func acceptsValidDomain() {
        let result = DomainValidator.validate("reddit.com")
        #expect(result == "reddit.com")
    }

    @Test func lowercasesAndTrims() {
        let result = DomainValidator.validate("  Reddit.COM  ")
        #expect(result == "reddit.com")
    }

    @Test func rejectsNoDot() {
        let result = DomainValidator.validate("reddit")
        #expect(result == nil)
    }

    @Test func rejectsEmpty() {
        let result = DomainValidator.validate("")
        #expect(result == nil)
    }

    @Test func rejectsWhitespaceOnly() {
        let result = DomainValidator.validate("   ")
        #expect(result == nil)
    }

    @Test func validateListDeduplicates() {
        let result = DomainValidator.validateList([
            "reddit.com", "Reddit.COM", "twitter.com", "reddit.com"
        ])
        #expect(result == ["reddit.com", "twitter.com"])
    }

    @Test func validateListFiltersInvalid() {
        let result = DomainValidator.validateList([
            "reddit.com", "invalid", "", "twitter.com"
        ])
        #expect(result == ["reddit.com", "twitter.com"])
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/ProfileDraftTests -only-testing:ForgeTests/DomainValidatorTests 2>&1 | tail -20`
Expected: FAIL — types not defined

- [ ] **Step 4: Implement ProfileDraft**

```swift
// ForgeKit/ProfileDraft.swift
import Foundation

public struct ProfileDraft: Sendable {
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var isBlocklist: Bool
    public var domains: [String]
    public var appBundleIDs: [String]
    public var expandSubdomains: Bool
    public var allowLocalNetwork: Bool
    public var clearBrowserCaches: Bool

    public init(
        name: String = "",
        iconName: String = "shield.fill",
        colorHex: String = "#007AFF",
        isBlocklist: Bool = true,
        domains: [String] = [],
        appBundleIDs: [String] = [],
        expandSubdomains: Bool = true,
        allowLocalNetwork: Bool = true,
        clearBrowserCaches: Bool = false
    ) {
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isBlocklist = isBlocklist
        self.domains = domains
        self.appBundleIDs = appBundleIDs
        self.expandSubdomains = expandSubdomains
        self.allowLocalNetwork = allowLocalNetwork
        self.clearBrowserCaches = clearBrowserCaches
    }

    public static var defaults: ProfileDraft { ProfileDraft() }
}
```

- [ ] **Step 5: Implement DomainValidator**

```swift
// ForgeKit/DomainValidator.swift
import Foundation

public enum DomainValidator {
    public static func validate(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, trimmed.contains(".") else { return nil }
        return trimmed
    }

    public static func validateList(_ inputs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for input in inputs {
            guard let validated = validate(input), !seen.contains(validated) else { continue }
            seen.insert(validated)
            result.append(validated)
        }
        return result
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/ProfileDraftTests -only-testing:ForgeTests/DomainValidatorTests 2>&1 | tail -20`
Expected: All 9 tests PASS

- [ ] **Step 7: Commit**

```bash
git add ForgeKit/ProfileDraft.swift ForgeKit/DomainValidator.swift ForgeTests/ProfileDraftTests.swift ForgeTests/DomainValidatorTests.swift
git commit -m "Add ProfileDraft and DomainValidator with TDD tests"
```

---

### Task 2: ProfileSerializer (TDD)

**Files:**
- Create: `ForgeTests/ProfileSerializerTests.swift`
- Create: `ForgeKit/ProfileSerializer.swift`

- [ ] **Step 1: Write failing tests**

```swift
// ForgeTests/ProfileSerializerTests.swift
import Testing
import Foundation
@testable import ForgeKit

@Suite("ProfileSerializer Tests")
struct ProfileSerializerTests {

    @Test func encodeDecodeRoundtrip() throws {
        let draft = ProfileDraft(
            name: "Work Mode",
            iconName: "briefcase.fill",
            colorHex: "#FF3B30",
            isBlocklist: true,
            domains: ["reddit.com", "twitter.com"],
            appBundleIDs: ["com.valvesoftware.steam"],
            expandSubdomains: true,
            allowLocalNetwork: false,
            clearBrowserCaches: true
        )

        let data = try ProfileSerializer.encode(draft)
        let decoded = try ProfileSerializer.decode(data)

        #expect(decoded.name == draft.name)
        #expect(decoded.iconName == draft.iconName)
        #expect(decoded.colorHex == draft.colorHex)
        #expect(decoded.isBlocklist == draft.isBlocklist)
        #expect(decoded.domains == draft.domains)
        #expect(decoded.appBundleIDs == draft.appBundleIDs)
        #expect(decoded.expandSubdomains == draft.expandSubdomains)
        #expect(decoded.allowLocalNetwork == draft.allowLocalNetwork)
        #expect(decoded.clearBrowserCaches == draft.clearBrowserCaches)
    }

    @Test func decodeRejectsInvalidJSON() {
        let badData = Data("not json".utf8)
        #expect(throws: (any Error).self) {
            try ProfileSerializer.decode(badData)
        }
    }

    @Test func encodedJSONIsHumanReadable() throws {
        let draft = ProfileDraft(name: "Test", domains: ["example.com"])
        let data = try ProfileSerializer.encode(draft)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"name\""))
        #expect(json.contains("\"Test\""))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/ProfileSerializerTests 2>&1 | tail -20`
Expected: FAIL — `ProfileSerializer` not defined

- [ ] **Step 3: Implement ProfileSerializer**

```swift
// ForgeKit/ProfileSerializer.swift
import Foundation

public enum ProfileSerializer {
    public static func encode(_ draft: ProfileDraft) throws -> Data {
        let preset = PresetProfileData(
            name: draft.name,
            iconName: draft.iconName,
            colorHex: draft.colorHex,
            isBlocklist: draft.isBlocklist,
            domains: draft.domains,
            appBundleIDs: draft.appBundleIDs,
            expandSubdomains: draft.expandSubdomains,
            allowLocalNetwork: draft.allowLocalNetwork,
            clearBrowserCaches: draft.clearBrowserCaches
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(preset)
    }

    public static func decode(_ data: Data) throws -> ProfileDraft {
        let preset = try JSONDecoder().decode(PresetProfileData.self, from: data)
        return ProfileDraft(
            name: preset.name,
            iconName: preset.iconName,
            colorHex: preset.colorHex,
            isBlocklist: preset.isBlocklist,
            domains: preset.domains,
            appBundleIDs: preset.appBundleIDs,
            expandSubdomains: preset.expandSubdomains,
            allowLocalNetwork: preset.allowLocalNetwork,
            clearBrowserCaches: preset.clearBrowserCaches
        )
    }
}
```

NOTE: `PresetProfileData` is currently defined in `Forge/Services/PresetProfileLoader.swift` (Forge app target), not ForgeKit. You will need to either:
- Move `PresetProfileData` to ForgeKit (recommended — it's a pure Codable struct), or
- Define a private `ProfileExportData` Codable struct in `ProfileSerializer.swift` with the same fields

The recommended approach: move `PresetProfileData` to `ForgeKit/PresetProfileData.swift`, make it `public`, and update `PresetProfileLoader` to import it from ForgeKit.

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/ProfileSerializerTests 2>&1 | tail -20`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add ForgeKit/ProfileSerializer.swift ForgeKit/PresetProfileData.swift ForgeTests/ProfileSerializerTests.swift Forge/Services/PresetProfileLoader.swift
git commit -m "Add ProfileSerializer with JSON encode/decode and move PresetProfileData to ForgeKit"
```

---

### Task 3: InstalledAppScanner

**Files:**
- Create: `Forge/Services/InstalledAppScanner.swift`

- [ ] **Step 1: Implement InstalledAppScanner**

```swift
// Forge/Services/InstalledAppScanner.swift
import Foundation

struct InstalledApp: Identifiable, Hashable {
    let id: String          // bundle ID
    let displayName: String
    let path: URL
}

enum InstalledAppScanner {
    private static let searchDirectories = [
        "/Applications",
        "/System/Applications",
    ]

    static func scan() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        var seenBundleIDs = Set<String>()
        let fileManager = FileManager.default

        for directory in searchDirectories {
            let dirURL = URL(fileURLWithPath: directory)
            guard let enumerator = fileManager.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                enumerator.skipDescendants()

                guard let bundle = Bundle(url: fileURL),
                      let bundleID = bundle.bundleIdentifier,
                      !seenBundleIDs.contains(bundleID) else { continue }

                let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? fileURL.deletingPathExtension().lastPathComponent

                seenBundleIDs.insert(bundleID)
                apps.append(InstalledApp(
                    id: bundleID,
                    displayName: displayName,
                    path: fileURL
                ))
            }
        }

        return apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Forge/Services/InstalledAppScanner.swift
git commit -m "Add InstalledAppScanner for enumerating installed macOS apps"
```

---

### Task 4: IconPickerView

**Files:**
- Create: `Forge/Views/Profiles/IconPickerView.swift`

- [ ] **Step 1: Implement IconPickerView**

```swift
// Forge/Views/Profiles/IconPickerView.swift
import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String

    private static let icons = [
        "shield.fill", "flame.fill", "book.fill", "gamecontroller.fill",
        "newspaper.fill", "tv.fill", "bubble.left.fill", "cart.fill",
        "briefcase.fill", "graduationcap.fill", "music.note", "film",
        "sportscourt.fill", "cup.and.saucer.fill", "airplane",
        "heart.fill", "star.fill", "bolt.fill", "leaf.fill", "moon.fill",
        "sun.max.fill", "eye.slash.fill", "hand.raised.fill",
        "clock.fill", "bell.slash.fill", "wifi.slash", "globe",
        "lock.fill", "desktopcomputer", "iphone",
    ]

    private let columns = Array(repeating: GridItem(.adaptive(minimum: 40)), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Self.icons, id: \.self) { icon in
                Button {
                    selectedIcon = icon
                } label: {
                    Image(systemName: icon)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                        .background(
                            selectedIcon == icon
                                ? Color.accentColor.opacity(0.2)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(
                            selectedIcon == icon ? .primary : .secondary
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Forge/Views/Profiles/IconPickerView.swift
git commit -m "Add IconPickerView with curated SF Symbol grid"
```

---

### Task 5: DomainListEditor

**Files:**
- Create: `Forge/Views/Profiles/DomainListEditor.swift`

- [ ] **Step 1: Implement DomainListEditor**

```swift
// Forge/Views/Profiles/DomainListEditor.swift
import SwiftUI
import ForgeKit

struct DomainListEditor: View {
    @Binding var domains: [String]
    @State private var newDomain = ""
    @State private var showingPasteSheet = false
    @State private var pasteText = ""

    var body: some View {
        Section("Domains") {
            ForEach(domains, id: \.self) { domain in
                HStack {
                    Text(domain)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(role: .destructive) {
                        domains.removeAll { $0 == domain }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("example.com", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { addDomain() }

                Button("Add") { addDomain() }
                    .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Button("Paste Multiple...") {
                pasteText = ""
                showingPasteSheet = true
            }
        }
        .sheet(isPresented: $showingPasteSheet) {
            VStack(spacing: 16) {
                Text("Paste Domains")
                    .font(.headline)
                Text("One domain per line")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $pasteText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(.separator)

                HStack {
                    Button("Cancel") {
                        showingPasteSheet = false
                    }
                    Spacer()
                    Button("Add Domains") {
                        let lines = pasteText.components(separatedBy: .newlines)
                        let validated = DomainValidator.validateList(lines)
                        let existing = Set(domains)
                        let newDomains = validated.filter { !existing.contains($0) }
                        domains.append(contentsOf: newDomains)
                        showingPasteSheet = false
                    }
                }
            }
            .padding()
            .frame(minWidth: 400, minHeight: 300)
        }
    }

    private func addDomain() {
        guard let validated = DomainValidator.validate(newDomain),
              !domains.contains(validated) else {
            newDomain = ""
            return
        }
        domains.append(validated)
        newDomain = ""
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Forge/Views/Profiles/DomainListEditor.swift
git commit -m "Add DomainListEditor with single add, paste multiple, and validation"
```

---

### Task 6: AppPickerView

**Files:**
- Create: `Forge/Views/Profiles/AppPickerView.swift`

- [ ] **Step 1: Implement AppPickerView**

```swift
// Forge/Views/Profiles/AppPickerView.swift
import SwiftUI

struct AppPickerView: View {
    @Binding var selectedBundleIDs: [String]
    @State private var installedApps: [InstalledApp] = []
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Apps")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List(filteredApps) { app in
                HStack(spacing: 12) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path))
                        .resizable()
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading) {
                        Text(app.displayName)
                            .font(.body)
                        Text(app.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedBundleIDs.contains(app.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(app.id)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 500)
        .task {
            installedApps = InstalledAppScanner.scan()
        }
    }

    private var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return installedApps }
        return installedApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func toggleSelection(_ bundleID: String) {
        if let index = selectedBundleIDs.firstIndex(of: bundleID) {
            selectedBundleIDs.remove(at: index)
        } else {
            selectedBundleIDs.append(bundleID)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Forge/Views/Profiles/AppPickerView.swift
git commit -m "Add AppPickerView with installed app scanning and selection"
```

---

### Task 7: ProfileEditorView

**Files:**
- Create: `Forge/Views/Profiles/ProfileEditorView.swift`

- [ ] **Step 1: Implement ProfileEditorView**

```swift
// Forge/Views/Profiles/ProfileEditorView.swift
import SwiftUI
import SwiftData
import ForgeKit

struct ProfileEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingProfile: BlockProfile?
    @State private var draft: ProfileDraft
    @State private var showingAppPicker = false
    @State private var profileColor: Color

    init(profile: BlockProfile? = nil) {
        self.existingProfile = profile
        if let profile {
            _draft = State(initialValue: ProfileDraft(
                name: profile.name,
                iconName: profile.iconName,
                colorHex: profile.colorHex,
                isBlocklist: profile.isBlocklist,
                domains: profile.domains,
                appBundleIDs: profile.appBundleIDs,
                expandSubdomains: profile.expandSubdomains,
                allowLocalNetwork: profile.allowLocalNetwork,
                clearBrowserCaches: profile.clearBrowserCaches
            ))
            _profileColor = State(initialValue: Color(hex: profile.colorHex) ?? .blue)
        } else {
            let defaults = ProfileDraft.defaults
            _draft = State(initialValue: defaults)
            _profileColor = State(initialValue: Color(hex: defaults.colorHex) ?? .blue)
        }
    }

    var body: some View {
        Form {
            // Identity
            Section("Identity") {
                TextField("Profile Name", text: $draft.name)
                    .textFieldStyle(.roundedBorder)

                IconPickerView(selectedIcon: $draft.iconName)

                ColorPicker("Color", selection: $profileColor, supportsOpacity: false)
                    .onChange(of: profileColor) {
                        draft.colorHex = profileColor.hexString
                    }
            }

            // Mode
            Section("Blocking Mode") {
                Picker("Mode", selection: $draft.isBlocklist) {
                    Text("Blocklist").tag(true)
                    Text("Allowlist").tag(false)
                }
                .pickerStyle(.segmented)
            }

            // Domains
            DomainListEditor(domains: $draft.domains)

            // Apps
            Section("Apps") {
                if draft.appBundleIDs.isEmpty {
                    Text("No apps selected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(draft.appBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button(role: .destructive) {
                                draft.appBundleIDs.removeAll { $0 == bundleID }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button("Choose Apps...") {
                    showingAppPicker = true
                }
            }

            // Options
            Section("Options") {
                Toggle("Expand common subdomains (www, m, mobile, api)", isOn: $draft.expandSubdomains)
                Toggle("Allow local network traffic", isOn: $draft.allowLocalNetwork)
                Toggle("Clear browser caches on block start", isOn: $draft.clearBrowserCaches)
            }

            // Import preset
            Section("Import Preset") {
                let presets = PresetProfileLoader.loadBundled()
                if !presets.isEmpty {
                    ForEach(presets, id: \.name) { preset in
                        Button(preset.name) {
                            draft.domains = preset.domains
                            draft.appBundleIDs = preset.appBundleIDs
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            AppPickerView(selectedBundleIDs: $draft.appBundleIDs)
        }
    }

    private func save() {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existingProfile {
            existingProfile.name = trimmedName
            existingProfile.iconName = draft.iconName
            existingProfile.colorHex = draft.colorHex
            existingProfile.isBlocklist = draft.isBlocklist
            existingProfile.domains = DomainValidator.validateList(draft.domains)
            existingProfile.appBundleIDs = draft.appBundleIDs
            existingProfile.expandSubdomains = draft.expandSubdomains
            existingProfile.allowLocalNetwork = draft.allowLocalNetwork
            existingProfile.clearBrowserCaches = draft.clearBrowserCaches
            existingProfile.updatedAt = .now
        } else {
            let profile = BlockProfile(
                name: trimmedName,
                iconName: draft.iconName,
                colorHex: draft.colorHex,
                isBlocklist: draft.isBlocklist,
                domains: DomainValidator.validateList(draft.domains),
                appBundleIDs: draft.appBundleIDs,
                expandSubdomains: draft.expandSubdomains,
                allowLocalNetwork: draft.allowLocalNetwork,
                clearBrowserCaches: draft.clearBrowserCaches
            )
            modelContext.insert(profile)
        }

        dismiss()
    }
}
```

NOTE: This references `Color(hex:)` and `Color.hexString` — these should already exist in the codebase (used by `ProfileCardView`). If `hexString` doesn't exist, add a computed property to `Color` that returns a hex string. Read `Forge/Views/Dashboard/ProfileCardView.swift` to check what extensions exist.

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Forge/Views/Profiles/ProfileEditorView.swift
git commit -m "Add ProfileEditorView with full form: identity, mode, domains, apps, options, presets"
```

---

### Task 8: Update ProfileListView + Import/Export

**Files:**
- Modify: `Forge/Views/Profiles/ProfileListView.swift`

- [ ] **Step 1: Read the current ProfileListView**

Read: `Forge/Views/Profiles/ProfileListView.swift`

- [ ] **Step 2: Rewrite ProfileListView with sheet presentation, toolbar, delete confirmation, and import/export**

```swift
// Forge/Views/Profiles/ProfileListView.swift
import SwiftUI
import SwiftData
import ForgeKit

struct ProfileListView: View {
    @Query(sort: \BlockProfile.sortOrder) private var profiles: [BlockProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var editingProfile: BlockProfile?
    @State private var showingNewProfile = false
    @State private var showingDeleteConfirm = false
    @State private var profileToDelete: BlockProfile?
    @State private var importError: String?
    @State private var showingImportError = false

    var body: some View {
        List {
            ForEach(profiles) { profile in
                HStack(spacing: 12) {
                    Image(systemName: profile.iconName)
                        .font(.title2)
                        .foregroundStyle(
                            Color(hex: profile.colorHex) ?? .accentColor
                        )
                        .frame(width: 32)

                    VStack(alignment: .leading) {
                        Text(profile.name)
                            .font(.headline)
                        Text(
                            "\(profile.domains.count) sites"
                            + (profile.appBundleIDs.isEmpty ? "" : " \u{00B7} \(profile.appBundleIDs.count) apps")
                            + " \u{00B7} "
                            + (profile.isBlocklist ? "Blocklist" : "Allowlist")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    editingProfile = profile
                }
                .contextMenu {
                    Button("Export...") {
                        exportProfile(profile)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        profileToDelete = profile
                        showingDeleteConfirm = true
                    }
                }
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem {
                Button("Import", systemImage: "square.and.arrow.down") {
                    importProfile()
                }
            }
            ToolbarItem {
                Button("Seed Presets", systemImage: "arrow.down.circle") {
                    seedPresetProfiles()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("New Profile", systemImage: "plus") {
                    showingNewProfile = true
                }
            }
        }
        .sheet(isPresented: $showingNewProfile) {
            ProfileEditorView()
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(profile: profile)
        }
        .confirmationDialog(
            "Delete Profile?",
            isPresented: $showingDeleteConfirm,
            presenting: profileToDelete
        ) { profile in
            Button("Delete", role: .destructive) {
                modelContext.delete(profile)
            }
        } message: { profile in
            Text("Delete \"\(profile.name)\"? This cannot be undone.")
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK") {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .overlay {
            if profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "shield.slash",
                    description: Text("Tap '+' to create a profile or 'Seed Presets' for built-in profiles")
                )
            }
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

    private func exportProfile(_ profile: BlockProfile) {
        let draft = ProfileDraft(
            name: profile.name,
            iconName: profile.iconName,
            colorHex: profile.colorHex,
            isBlocklist: profile.isBlocklist,
            domains: profile.domains,
            appBundleIDs: profile.appBundleIDs,
            expandSubdomains: profile.expandSubdomains,
            allowLocalNetwork: profile.allowLocalNetwork,
            clearBrowserCaches: profile.clearBrowserCaches
        )

        guard let data = try? ProfileSerializer.encode(draft) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(profile.name).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
        }
    }

    private func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try Data(contentsOf: url)
                let draft = try ProfileSerializer.decode(data)
                let profile = BlockProfile(
                    name: draft.name,
                    iconName: draft.iconName,
                    colorHex: draft.colorHex,
                    isBlocklist: draft.isBlocklist,
                    domains: draft.domains,
                    appBundleIDs: draft.appBundleIDs,
                    expandSubdomains: draft.expandSubdomains,
                    allowLocalNetwork: draft.allowLocalNetwork,
                    clearBrowserCaches: draft.clearBrowserCaches
                )
                modelContext.insert(profile)
            } catch {
                importError = error.localizedDescription
                showingImportError = true
            }
        }
    }
}
```

NOTE: The `.sheet(item:)` modifier requires `BlockProfile` to conform to `Identifiable`. It already does via its `id` property. However, `.sheet(item:)` expects an optional `Binding<Identifiable?>`. Verify this compiles. If not, use a separate `Bool` + the profile reference pattern.

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Forge/Views/Profiles/ProfileListView.swift
git commit -m "Update ProfileListView with editor sheets, import/export, delete confirmation"
```

---

### Task 9: Run All Tests and Final Build Verification

**Files:** None (verification only)

- [ ] **Step 1: Run all unit tests**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 2: Run full build**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Verify all new files are tracked**

Run: `git status`
Expected: Clean working tree

- [ ] **Step 4: Review commit log**

Run: `git log --oneline -10`
Expected: All profile editor commits in order
