# Phase 5b: Scheduling

**Date:** 2026-03-28
**Status:** Approved
**Scope:** Schedule editor UI, ScheduleEvaluator service, sidebar navigation update

---

## Goal

Users can create recurring schedules that automatically start blocks at specified times on specified weekdays. The `ScheduleEvaluator` runs in the background and triggers blocks via `BlockEngine` when a schedule's time window is active.

---

## Architecture

### BlockSchedule Model Update

The existing `BlockSchedule` model references profiles by `profileName: String`. This is fragile — profile renames break the reference. Update to use `profileID: UUID` for the link, keeping `profileName: String` as a display cache (read from the profile at creation time, not used for lookup).

Add `@Attribute(.unique) var id: UUID` for stable identity.

```swift
@Model
final class BlockSchedule {
    @Attribute(.unique) var id: UUID
    var profileID: UUID          // links to BlockProfile.id
    var profileName: String      // display cache
    var weekdays: [Int]          // 1=Sunday, 2=Monday, ..., 7=Saturday (Calendar convention)
    var startTime: Date          // only hour+minute used
    var endTime: Date            // only hour+minute used
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

### ScheduleEvaluator

Runs on a 30-second `Timer` while the app is active. On each tick:

1. Fetch all enabled `BlockSchedule` records from SwiftData
2. Get current weekday and time
3. For each schedule: check if current weekday is in `weekdays` and current time is within `startTime...endTime`
4. If matched and no block is active for this profile → start a block via `BlockEngine`
5. Handle overnight spans: if `startTime > endTime` (e.g., 10 PM → 6 AM), the window wraps across midnight
6. Handle wake-from-sleep: on wake, evaluate immediately (the timer fires naturally)
7. Avoid duplicate blocks: skip if `appState.isBlockActive` and `appState.activeProfileID == schedule.profileID`

**Time comparison:** Extract hour+minute from `startTime`/`endTime` using `Calendar.current`, compare against current hour+minute. Do not compare full `Date` objects (the date component is irrelevant — only the time-of-day matters).

**ScheduleMatch logic (ForgeKit, testable):**

```swift
public enum ScheduleMatch {
    /// Check if a given weekday + time falls within a schedule's window.
    public static func isActive(
        weekday: Int,           // 1-7
        hour: Int,              // 0-23
        minute: Int,            // 0-59
        scheduleWeekdays: [Int],
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int
    ) -> Bool
}
```

This is the core logic extracted for unit testing without SwiftData or Timer dependencies.

### Navigation

Add `schedules` case to `SidebarItem` enum in `AppState.swift`. Wire it to `ScheduleListView` in `ContentView.swift`.

---

## Components

### ScheduleListView

List of all schedules as cards:
- Profile icon + name + color
- Weekday chips (Mon, Tue, etc. — highlighted if active)
- Time range (e.g., "9:00 AM – 5:00 PM")
- Enabled/disabled toggle
- "+" toolbar button for new schedule
- Tap to edit (sheet)
- Swipe-to-delete with confirmation

### ScheduleEditorView

Sheet form:
- Profile picker (dropdown of all profiles from SwiftData)
- Weekday selector (multi-select chips: S M T W T F S)
- Start time picker (`DatePicker` with `.hourAndMinute`)
- End time picker (`DatePicker` with `.hourAndMinute`)
- Enabled toggle
- Cancel / Save toolbar buttons

Uses a `ScheduleDraft` struct (same pattern as `ProfileDraft`) to avoid SwiftData auto-save.

### ScheduleDraft (ForgeKit)

```swift
public struct ScheduleDraft: Sendable {
    public var profileID: UUID?
    public var profileName: String
    public var weekdays: [Int]
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int
    public var isEnabled: Bool
}
```

Stores time as hour+minute integers, not `Date` — avoids date-component confusion.

---

## Files

### Create

| File | Purpose |
|------|---------|
| `ForgeKit/ScheduleDraft.swift` | Draft struct for schedule editor |
| `ForgeKit/ScheduleMatch.swift` | Pure logic: is a schedule active for a given weekday+time? |
| `Forge/Views/Schedules/ScheduleListView.swift` | Schedule list with cards |
| `Forge/Views/Schedules/ScheduleEditorView.swift` | Schedule editor sheet |
| `Forge/Views/Schedules/WeekdayPicker.swift` | Multi-select weekday chip selector |
| `ForgeTests/ScheduleMatchTests.swift` | Schedule matching logic tests |
| `ForgeTests/ScheduleDraftTests.swift` | Draft defaults tests |

### Modify

| File | Change |
|------|--------|
| `Forge/Models/BlockSchedule.swift` | Add `id: UUID`, change `profileName` to `profileID: UUID` + cache |
| `Forge/Services/ScheduleEvaluator.swift` | Replace stub with timer-based evaluator |
| `Forge/App/AppState.swift` | Add `schedules` to `SidebarItem` |
| `Forge/App/ContentView.swift` | Wire `ScheduleListView` to sidebar |
| `Forge/App/ForgeApp.swift` | Start `ScheduleEvaluator` on launch |

---

## Testing

**Unit tests (ForgeKit scheme):**
- `ScheduleMatch.isActive`: same-day window (9 AM – 5 PM), inside → true, outside → false
- `ScheduleMatch.isActive`: overnight window (10 PM – 6 AM), 11 PM → true, 7 AM → false, 2 AM → true
- `ScheduleMatch.isActive`: weekday not in list → false
- `ScheduleMatch.isActive`: boundary: exactly at start time → true, exactly at end time → false
- `ScheduleDraft.defaults`: expected values

---

## Edge Cases

| Case | Behavior |
|------|----------|
| Overnight span (10 PM → 6 AM) | Active if time >= start OR time < end (on correct weekdays) |
| Block already active for same profile | Skip — don't start duplicate |
| Block active for different profile | Skip — only one block at a time |
| App launches during active schedule window | ScheduleEvaluator fires immediately, starts block |
| Profile deleted while schedule exists | Schedule becomes orphaned — evaluator skips schedules with no matching profile |
| All weekdays deselected | Schedule never fires (effectively disabled) |
