# Phase 5a: Profile Editor

**Date:** 2026-03-28
**Status:** Approved
**Scope:** Profile CRUD, domain list editing, app picker, icon/color selection, import/export as JSON

---

## Goal

Users can create, edit, and delete blocking profiles through a full-featured editor. Each profile defines which sites and apps to block, the blocking mode, and per-profile options. Profiles can be exported as JSON and imported from JSON files.

---

## Architecture

### Editor State: ProfileDraft

The editor works on a `ProfileDraft` struct — a plain value type mirroring `BlockProfile` fields. This avoids SwiftData auto-save on mutation. On "Save", the draft is written to a `BlockProfile` model (new or existing). On "Cancel", the draft is discarded.

```swift
struct ProfileDraft {
    var name: String
    var iconName: String
    var colorHex: String
    var isBlocklist: Bool
    var domains: [String]
    var appBundleIDs: [String]
    var expandSubdomains: Bool
    var allowLocalNetwork: Bool
    var clearBrowserCaches: Bool

    static var defaults: ProfileDraft { ... }  // sensible defaults for new profile
    init(name:iconName:colorHex:isBlocklist:domains:appBundleIDs:expandSubdomains:allowLocalNetwork:clearBrowserCaches:)
}
```

`ProfileDraft` lives in ForgeKit (testable). The Forge app creates a draft from a `BlockProfile` at the call site: `ProfileDraft(name: profile.name, iconName: profile.iconName, ...)`.

### Editor Mode

`ProfileEditorView` takes an optional `BlockProfile?`:
- **nil** → create mode (starts with `ProfileDraft.defaults`)
- **non-nil** → edit mode (starts with draft initialized from the existing profile)

On Save in create mode: insert a new `BlockProfile` into SwiftData.
On Save in edit mode: update the existing `BlockProfile`'s fields from the draft.

### Navigation

`ProfileListView` presents `ProfileEditorView` as a **sheet** (modal). The list has a "+" toolbar button for new profiles. Tapping an existing profile opens the editor pre-filled. Swipe-to-delete with confirmation alert.

---

## Components

### ProfileEditorView

Main form with sections:

**Identity section:**
- Name text field
- Icon picker (inline grid of ~30 curated SF Symbols)
- Color picker (SwiftUI `ColorPicker`, converts to/from hex string)

**Mode section:**
- Segmented picker: Blocklist / Allowlist

**Domains section:**
- `DomainListEditor` component (see below)

**Apps section:**
- `AppPickerView` component (see below)

**Options section:**
- Toggle: Expand common subdomains (www, m, mobile, api)
- Toggle: Allow local network traffic
- Toggle: Clear browser caches on block start

**Import preset section:**
- Picker dropdown with built-in presets (Social Media, News, Gaming)
- Selecting a preset replaces the current domains and appBundleIDs

**Toolbar:**
- Cancel button (dismiss sheet)
- Save button (validate → write to SwiftData → dismiss)

### DomainListEditor

Manages the `domains: [String]` array on the draft.

- Text field with "Add" button for single domain entry
- "Paste multiple" button opens a `TextEditor` sheet for pasting newline-separated domains
- Each domain shown as a row with delete button
- Validation delegated to `DomainValidator` (ForgeKit)
- Duplicate domains silently ignored

### DomainValidator (ForgeKit)

Pure logic, testable:

```swift
public enum DomainValidator {
    /// Normalize and validate a domain string.
    /// Returns nil if invalid (empty, no dot).
    public static func validate(_ input: String) -> String?

    /// Validate and deduplicate a list of domain strings.
    public static func validateList(_ inputs: [String]) -> [String]
}
```

Rules: strip whitespace, lowercase, reject empty strings and strings without a dot. `"  Reddit.COM  "` → `"reddit.com"`. `"reddit"` → nil.

### AppPickerView

Presented as a sheet from the Apps section.

- Uses `InstalledAppScanner` to enumerate installed apps
- Each app shown with icon + display name + bundle ID
- Search field to filter by name
- Checkmark toggle for selection
- Selected bundle IDs written back to draft's `appBundleIDs`
- Sorted alphabetically by display name

### InstalledAppScanner (Forge/Services)

Scans `/Applications` and `/System/Applications` recursively for `.app` bundles:

```swift
struct InstalledApp: Identifiable {
    let id: String         // bundle ID
    let displayName: String
    let path: URL
}

enum InstalledAppScanner {
    static func scan() -> [InstalledApp]
}
```

App icons loaded lazily in the view via `NSWorkspace.shared.icon(forFile:)`.

### IconPickerView

Inline grid of ~30 curated SF Symbols relevant to focus/productivity:

```
shield.fill, flame.fill, book.fill, gamecontroller.fill,
newspaper.fill, tv.fill, bubble.left.fill, cart.fill,
briefcase.fill, graduationcap.fill, music.note, film,
sportscourt.fill, cup.and.saucer.fill, airplane,
heart.fill, star.fill, bolt.fill, leaf.fill, moon.fill,
sun.max.fill, eye.slash.fill, hand.raised.fill,
clock.fill, bell.slash.fill, wifi.slash, globe,
lock.fill, desktopcomputer, iphone
```

Displayed as `LazyVGrid` with 6 columns. Selected icon highlighted with accent color.

### ProfileImportExport

Separated into logic (ForgeKit-testable) and UI (Forge views):

**Logic (ForgeKit):**

```swift
public enum ProfileSerializer {
    public static func encode(_ draft: ProfileDraft) throws -> Data
    public static func decode(_ data: Data) throws -> ProfileDraft
}
```

Uses `PresetProfileData` as the JSON format (already exists and is `Codable`). Encoding maps `ProfileDraft` → `PresetProfileData` → JSON. Decoding maps JSON → `PresetProfileData` → `ProfileDraft`.

**UI (Forge):**
- Export: context menu on profile row in `ProfileListView`, calls `ProfileSerializer.encode`, presents `NSSavePanel`
- Import: toolbar button in `ProfileListView`, presents `NSOpenPanel`, calls `ProfileSerializer.decode`, creates new `BlockProfile`
- Error alert shown if JSON is invalid

---

## Files

### Create

| File | Purpose |
|------|---------|
| `ForgeKit/ProfileDraft.swift` | `ProfileDraft` struct with defaults and field-by-field init |
| `ForgeKit/DomainValidator.swift` | Domain validation and normalization logic |
| `ForgeKit/ProfileSerializer.swift` | Encode/decode ProfileDraft to/from JSON |
| `Forge/Views/Profiles/ProfileEditorView.swift` | Main editor form |
| `Forge/Views/Profiles/DomainListEditor.swift` | Domain list add/remove/paste UI |
| `Forge/Views/Profiles/AppPickerView.swift` | Installed app browser with selection |
| `Forge/Views/Profiles/IconPickerView.swift` | Curated SF Symbol grid |
| `Forge/Services/InstalledAppScanner.swift` | Scan /Applications for .app bundles |
| `ForgeTests/ProfileDraftTests.swift` | Draft defaults, field init |
| `ForgeTests/DomainValidatorTests.swift` | Validation rules, normalization, deduplication |
| `ForgeTests/ProfileSerializerTests.swift` | Encode/decode roundtrip |

### Modify

| File | Change |
|------|--------|
| `Forge/Views/Profiles/ProfileListView.swift` | Add toolbar buttons (+, import), sheet presentation, delete confirmation, export context menu |

---

## Validation Rules

| Field | Rule |
|-------|------|
| Name | Non-empty, trimmed |
| Domains | Each must contain at least one dot, lowercased, trimmed, no duplicates |
| Icon | Must be non-empty (defaults to "shield.fill") |
| Color | Must be valid hex (defaults to "#007AFF") |

Save is disabled when name is empty.

---

## Testing

**Unit tests (ForgeKit scheme):**
- `ProfileDraft.defaults` has expected values (name empty, icon "shield.fill", etc.)
- `DomainValidator.validate`: accepts "reddit.com", rejects "reddit", strips whitespace, lowercases
- `DomainValidator.validateList`: deduplicates, preserves order of first occurrence
- `ProfileSerializer`: encode → decode roundtrip preserves all fields
- `ProfileSerializer.decode`: rejects invalid JSON with descriptive error

**Build verification:**
- Full project compiles
- Profile editor sheet opens and dismisses correctly
