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
}
```

`ProfileDraft` can be initialized from a `BlockProfile` (edit) or with defaults (create).

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

Manages the `domains: [String]` array.

- Text field with "Add" button for single domain entry
- "Paste multiple" button opens a `TextEditor` sheet for pasting newline-separated domains
- Each domain shown as a row with delete button
- **Validation:** Strip whitespace, lowercase, reject empty strings and strings without a dot
- Duplicate domains silently ignored

### AppPickerView

Presented as a sheet from the Apps section.

- Enumerates installed apps by scanning `/Applications` and `/System/Applications` for `.app` bundles
- Each app shown with icon (`NSWorkspace.shared.icon(forFile:)`) + display name + bundle ID
- Search field to filter by name
- Checkmark toggle for selection
- Selected bundle IDs written back to draft's `appBundleIDs`
- Sorted alphabetically by display name

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

**Export:**
- Button in `ProfileListView` toolbar or context menu per profile
- Encodes profile as `PresetProfileData` JSON
- Presents `NSSavePanel` with `.json` file type
- Default filename: `{profile-name}.json`

**Import:**
- Button in `ProfileListView` toolbar
- Presents `NSOpenPanel` for `.json` files
- Decodes `PresetProfileData` from file
- Creates new `BlockProfile` from imported data
- Shows error alert if JSON is invalid

Uses existing `PresetProfileData` struct for the JSON format. Import creates a new profile with a fresh UUID, `isPinned: false`, and next available `sortOrder`.

---

## Files

### Create

| File | Purpose |
|------|---------|
| `ForgeKit/ProfileDraft.swift` | `ProfileDraft` struct with init from `BlockProfile` and defaults |
| `Forge/Views/Profiles/ProfileEditorView.swift` | Main editor form |
| `Forge/Views/Profiles/DomainListEditor.swift` | Domain list add/remove/paste/validate |
| `Forge/Views/Profiles/AppPickerView.swift` | Installed app browser with selection |
| `Forge/Views/Profiles/IconPickerView.swift` | Curated SF Symbol grid |
| `Forge/Services/InstalledAppScanner.swift` | Scan /Applications for .app bundles |
| `Forge/Services/ProfileImportExport.swift` | JSON export via NSSavePanel, import via NSOpenPanel |
| `ForgeTests/ProfileDraftTests.swift` | Draft init, validation |
| `ForgeTests/DomainValidationTests.swift` | Domain validation logic |
| `ForgeTests/InstalledAppScannerTests.swift` | App scanning logic |

### Modify

| File | Change |
|------|--------|
| `Forge/Views/Profiles/ProfileListView.swift` | Add toolbar buttons, sheet presentation, delete confirmation, context menu |

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
- `ProfileDraft` init from defaults has correct values
- `ProfileDraft` init from `BlockProfile` copies all fields
- Domain validation: accepts "reddit.com", rejects "reddit", strips whitespace, lowercases
- Domain deduplication
- `InstalledAppScanner` finds at least Safari and Finder on any Mac

**Build verification:**
- Full project compiles
- Profile editor sheet opens and dismisses correctly
