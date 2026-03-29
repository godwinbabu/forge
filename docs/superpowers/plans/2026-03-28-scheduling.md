# Scheduling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recurring schedules that automatically start blocks at specified times on specified weekdays, with a full editor UI and background evaluator.

**Architecture:** `ScheduleMatch` (ForgeKit) provides pure testable logic for time-window matching. `ScheduleEvaluator` (Forge) polls every 30s and starts blocks via `BlockEngine`. `ScheduleEditorView` uses a `ScheduleDraft` struct (ForgeKit) to avoid SwiftData auto-save. `WeekdayPicker` is a reusable chip selector.

**Tech Stack:** SwiftUI, SwiftData, ForgeKit, Swift Testing, Timer

---

## File Structure

| File | Responsibility |
|------|---------------|
| `ForgeKit/ScheduleDraft.swift` (create) | Editor state struct with defaults |
| `ForgeKit/ScheduleMatch.swift` (create) | Pure logic: is a schedule active for a given weekday+time? |
| `Forge/Views/Schedules/WeekdayPicker.swift` (create) | Multi-select weekday chip selector |
| `Forge/Views/Schedules/ScheduleEditorView.swift` (create) | Schedule editor sheet |
| `Forge/Views/Schedules/ScheduleListView.swift` (create) | Schedule list with cards |
| `Forge/Models/BlockSchedule.swift` (modify) | Add id, change to profileID + hour/minute ints |
| `Forge/Services/ScheduleEvaluator.swift` (modify) | Replace stub with timer-based evaluator |
| `Forge/App/AppState.swift` (modify) | Add `schedules` to SidebarItem |
| `Forge/App/ContentView.swift` (modify) | Wire ScheduleListView |
| `Forge/App/ForgeApp.swift` (modify) | Start ScheduleEvaluator on launch |
| `ForgeTests/ScheduleMatchTests.swift` (create) | Schedule matching logic tests |
| `ForgeTests/ScheduleDraftTests.swift` (create) | Draft defaults tests |

---

### Task 1: ScheduleDraft + ScheduleMatch (TDD)

**Files:**
- Create: `ForgeTests/ScheduleDraftTests.swift`
- Create: `ForgeTests/ScheduleMatchTests.swift`
- Create: `ForgeKit/ScheduleDraft.swift`
- Create: `ForgeKit/ScheduleMatch.swift`

- [ ] **Step 1: Write failing tests for ScheduleDraft**

```swift
// ForgeTests/ScheduleDraftTests.swift
import Testing
@testable import ForgeKit

@Suite("ScheduleDraft Tests")
struct ScheduleDraftTests {

    @Test func defaultsHaveExpectedValues() {
        let draft = ScheduleDraft.defaults
        #expect(draft.profileID == nil)
        #expect(draft.profileName == "")
        #expect(draft.weekdays.isEmpty)
        #expect(draft.startHour == 9)
        #expect(draft.startMinute == 0)
        #expect(draft.endHour == 17)
        #expect(draft.endMinute == 0)
        #expect(draft.isEnabled == true)
    }

    @Test func initWithAllFields() {
        let id = UUID()
        let draft = ScheduleDraft(
            profileID: id,
            profileName: "Work",
            weekdays: [2, 3, 4, 5, 6],
            startHour: 8,
            startMinute: 30,
            endHour: 16,
            endMinute: 45,
            isEnabled: false
        )
        #expect(draft.profileID == id)
        #expect(draft.profileName == "Work")
        #expect(draft.weekdays == [2, 3, 4, 5, 6])
        #expect(draft.startHour == 8)
        #expect(draft.startMinute == 30)
        #expect(draft.endHour == 16)
        #expect(draft.endMinute == 45)
        #expect(draft.isEnabled == false)
    }
}
```

- [ ] **Step 2: Write failing tests for ScheduleMatch**

```swift
// ForgeTests/ScheduleMatchTests.swift
import Testing
@testable import ForgeKit

@Suite("ScheduleMatch Tests")
struct ScheduleMatchTests {

    // Same-day window: 9:00 AM - 5:00 PM on weekdays
    @Test func insideSameDayWindow() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 12, minute: 0,
            scheduleWeekdays: [2, 3, 4, 5, 6],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(result == true)
    }

    @Test func outsideSameDayWindow() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 18, minute: 0,
            scheduleWeekdays: [2, 3, 4, 5, 6],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(result == false)
    }

    @Test func wrongWeekday() {
        let result = ScheduleMatch.isActive(
            weekday: 1, hour: 12, minute: 0, // Sunday
            scheduleWeekdays: [2, 3, 4, 5, 6], // Mon-Fri
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(result == false)
    }

    // Overnight window: 10:00 PM - 6:00 AM
    @Test func insideOvernightWindowLateNight() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 23, minute: 0,
            scheduleWeekdays: [2],
            startHour: 22, startMinute: 0,
            endHour: 6, endMinute: 0
        )
        #expect(result == true)
    }

    @Test func insideOvernightWindowEarlyMorning() {
        // 2 AM on Tuesday — the schedule started Monday 10 PM
        // Weekday 2 = Monday in the schedule, but now it's Tuesday (3)
        // For overnight, we check if PREVIOUS day is in weekdays
        // Actually: at 2 AM we check if current weekday OR previous weekday matches
        let result = ScheduleMatch.isActive(
            weekday: 3, hour: 2, minute: 0, // Tuesday 2 AM
            scheduleWeekdays: [2], // Monday
            startHour: 22, startMinute: 0,
            endHour: 6, endMinute: 0
        )
        #expect(result == true)
    }

    @Test func outsideOvernightWindow() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 7, minute: 0,
            scheduleWeekdays: [2],
            startHour: 22, startMinute: 0,
            endHour: 6, endMinute: 0
        )
        #expect(result == false)
    }

    // Boundary cases
    @Test func exactlyAtStartTime() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 9, minute: 0,
            scheduleWeekdays: [2],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(result == true)
    }

    @Test func exactlyAtEndTime() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 17, minute: 0,
            scheduleWeekdays: [2],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(result == false)
    }

    @Test func emptyWeekdaysNeverActive() {
        let result = ScheduleMatch.isActive(
            weekday: 2, hour: 12, minute: 0,
            scheduleWeekdays: [],
            startHour: 9, startMinute: 0,
            endHour: 17, endMinute: 0
        )
        #expect(result == false)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/ScheduleDraftTests -only-testing:ForgeTests/ScheduleMatchTests 2>&1 | tail -20`
Expected: FAIL — types not defined

- [ ] **Step 4: Implement ScheduleDraft**

```swift
// ForgeKit/ScheduleDraft.swift
import Foundation

public struct ScheduleDraft: Sendable {
    public var profileID: UUID?
    public var profileName: String
    public var weekdays: [Int]      // 1=Sunday ... 7=Saturday
    public var startHour: Int       // 0-23
    public var startMinute: Int     // 0-59
    public var endHour: Int
    public var endMinute: Int
    public var isEnabled: Bool

    public init(
        profileID: UUID? = nil,
        profileName: String = "",
        weekdays: [Int] = [],
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 17,
        endMinute: Int = 0,
        isEnabled: Bool = true
    ) {
        self.profileID = profileID
        self.profileName = profileName
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = isEnabled
    }

    public static var defaults: ScheduleDraft { ScheduleDraft() }
}
```

- [ ] **Step 5: Implement ScheduleMatch**

```swift
// ForgeKit/ScheduleMatch.swift
import Foundation

public enum ScheduleMatch {
    /// Check if a given weekday + time falls within a schedule's window.
    /// Weekday: 1=Sunday, 2=Monday, ..., 7=Saturday (Calendar convention).
    /// Handles overnight spans (startHour > endHour) by checking previous day's weekday.
    public static func isActive(
        weekday: Int,
        hour: Int,
        minute: Int,
        scheduleWeekdays: [Int],
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) -> Bool {
        guard !scheduleWeekdays.isEmpty else { return false }

        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        if startMinutes < endMinutes {
            // Same-day window: e.g. 9:00 - 17:00
            return scheduleWeekdays.contains(weekday)
                && currentMinutes >= startMinutes
                && currentMinutes < endMinutes
        } else {
            // Overnight window: e.g. 22:00 - 6:00
            // Active if: (today's weekday matches AND time >= start)
            //         OR (yesterday's weekday matches AND time < end)
            let previousWeekday = weekday == 1 ? 7 : weekday - 1

            if currentMinutes >= startMinutes && scheduleWeekdays.contains(weekday) {
                return true
            }
            if currentMinutes < endMinutes && scheduleWeekdays.contains(previousWeekday) {
                return true
            }
            return false
        }
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `xcodebuild test -scheme ForgeKit -destination 'platform=macOS' -only-testing:ForgeTests/ScheduleDraftTests -only-testing:ForgeTests/ScheduleMatchTests 2>&1 | tail -20`
Expected: All 11 tests PASS

- [ ] **Step 7: Commit**

```bash
git add ForgeKit/ScheduleDraft.swift ForgeKit/ScheduleMatch.swift ForgeTests/ScheduleDraftTests.swift ForgeTests/ScheduleMatchTests.swift
git commit -m "Add ScheduleDraft and ScheduleMatch with TDD tests"
```

---

### Task 2: Update BlockSchedule Model

**Files:**
- Modify: `Forge/Models/BlockSchedule.swift`

- [ ] **Step 1: Read the current BlockSchedule model**

Read: `Forge/Models/BlockSchedule.swift`

- [ ] **Step 2: Rewrite BlockSchedule with id, profileID, and hour/minute ints**

```swift
// Forge/Models/BlockSchedule.swift
import Foundation
import SwiftData

@Model
final class BlockSchedule {
    @Attribute(.unique) var id: UUID
    var profileID: UUID
    var profileName: String     // display cache
    var weekdays: [Int]         // 1=Sunday ... 7=Saturday
    var startHour: Int          // 0-23
    var startMinute: Int        // 0-59
    var endHour: Int
    var endMinute: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        profileID: UUID,
        profileName: String,
        weekdays: [Int] = [],
        startHour: Int = 9,
        startMinute: Int = 0,
        endHour: Int = 17,
        endMinute: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.profileID = profileID
        self.profileName = profileName
        self.weekdays = weekdays
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = isEnabled
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Forge/Models/BlockSchedule.swift
git commit -m "Update BlockSchedule model with id, profileID, and hour/minute fields"
```

---

### Task 3: WeekdayPicker + ScheduleEditorView

**Files:**
- Create: `Forge/Views/Schedules/WeekdayPicker.swift`
- Create: `Forge/Views/Schedules/ScheduleEditorView.swift`

- [ ] **Step 1: Create the Schedules directory and WeekdayPicker**

```swift
// Forge/Views/Schedules/WeekdayPicker.swift
import SwiftUI

struct WeekdayPicker: View {
    @Binding var selectedWeekdays: [Int]

    // 1=Sun, 2=Mon, ..., 7=Sat
    private static let labels = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.labels, id: \.0) { weekday, label in
                Button {
                    toggleWeekday(weekday)
                } label: {
                    Text(label)
                        .font(.caption.bold())
                        .frame(width: 32, height: 32)
                        .background(
                            selectedWeekdays.contains(weekday)
                                ? Color.accentColor
                                : Color.secondary.opacity(0.2),
                            in: Circle()
                        )
                        .foregroundStyle(
                            selectedWeekdays.contains(weekday) ? .white : .primary
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleWeekday(_ weekday: Int) {
        if let index = selectedWeekdays.firstIndex(of: weekday) {
            selectedWeekdays.remove(at: index)
        } else {
            selectedWeekdays.append(weekday)
            selectedWeekdays.sort()
        }
    }
}
```

- [ ] **Step 2: Create ScheduleEditorView**

```swift
// Forge/Views/Schedules/ScheduleEditorView.swift
import SwiftUI
import SwiftData
import ForgeKit

struct ScheduleEditorView: View {
    @Query(sort: \BlockProfile.sortOrder) private var profiles: [BlockProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingSchedule: BlockSchedule?
    @State private var draft: ScheduleDraft

    init(schedule: BlockSchedule? = nil) {
        self.existingSchedule = schedule
        if let schedule {
            _draft = State(initialValue: ScheduleDraft(
                profileID: schedule.profileID,
                profileName: schedule.profileName,
                weekdays: schedule.weekdays,
                startHour: schedule.startHour,
                startMinute: schedule.startMinute,
                endHour: schedule.endHour,
                endMinute: schedule.endMinute,
                isEnabled: schedule.isEnabled
            ))
        } else {
            _draft = State(initialValue: ScheduleDraft.defaults)
        }
    }

    var body: some View {
        Form {
            Section("Profile") {
                Picker("Profile", selection: $draft.profileID) {
                    Text("Select a profile").tag(UUID?.none)
                    ForEach(profiles) { profile in
                        HStack {
                            Image(systemName: profile.iconName)
                            Text(profile.name)
                        }
                        .tag(Optional(profile.id))
                    }
                }
                .onChange(of: draft.profileID) {
                    if let profile = profiles.first(where: { $0.id == draft.profileID }) {
                        draft.profileName = profile.name
                    }
                }
            }

            Section("Days") {
                WeekdayPicker(selectedWeekdays: $draft.weekdays)
            }

            Section("Time") {
                HStack {
                    Text("Start")
                    Spacer()
                    TimePicker(hour: $draft.startHour, minute: $draft.startMinute)
                }
                HStack {
                    Text("End")
                    Spacer()
                    TimePicker(hour: $draft.endHour, minute: $draft.endMinute)
                }
            }

            Section {
                Toggle("Enabled", isOn: $draft.isEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 350)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(draft.profileID == nil || draft.weekdays.isEmpty)
            }
        }
    }

    private func save() {
        guard let profileID = draft.profileID else { return }

        if let existingSchedule {
            existingSchedule.profileID = profileID
            existingSchedule.profileName = draft.profileName
            existingSchedule.weekdays = draft.weekdays
            existingSchedule.startHour = draft.startHour
            existingSchedule.startMinute = draft.startMinute
            existingSchedule.endHour = draft.endHour
            existingSchedule.endMinute = draft.endMinute
            existingSchedule.isEnabled = draft.isEnabled
            existingSchedule.updatedAt = .now
        } else {
            let schedule = BlockSchedule(
                profileID: profileID,
                profileName: draft.profileName,
                weekdays: draft.weekdays,
                startHour: draft.startHour,
                startMinute: draft.startMinute,
                endHour: draft.endHour,
                endMinute: draft.endMinute,
                isEnabled: draft.isEnabled
            )
            modelContext.insert(schedule)
        }

        dismiss()
    }
}

// Simple hour+minute picker using two wheels
struct TimePicker: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 2) {
            Picker("", selection: $hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .frame(width: 60)

            Text(":")

            Picker("", selection: $minute) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .frame(width: 60)
        }
    }
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Forge/Views/Schedules/WeekdayPicker.swift Forge/Views/Schedules/ScheduleEditorView.swift
git commit -m "Add WeekdayPicker and ScheduleEditorView with profile picker and time selection"
```

---

### Task 4: ScheduleListView

**Files:**
- Create: `Forge/Views/Schedules/ScheduleListView.swift`

- [ ] **Step 1: Implement ScheduleListView**

```swift
// Forge/Views/Schedules/ScheduleListView.swift
import SwiftUI
import SwiftData

struct ScheduleListView: View {
    @Query(sort: \BlockSchedule.createdAt) private var schedules: [BlockSchedule]
    @Environment(\.modelContext) private var modelContext

    @State private var editingSchedule: BlockSchedule?
    @State private var showingNewSchedule = false
    @State private var showingDeleteConfirm = false
    @State private var scheduleToDelete: BlockSchedule?

    var body: some View {
        List {
            ForEach(schedules) { schedule in
                scheduleRow(schedule)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingSchedule = schedule
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            scheduleToDelete = schedule
                            showingDeleteConfirm = true
                        }
                    }
            }
        }
        .navigationTitle("Schedules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Schedule", systemImage: "plus") {
                    showingNewSchedule = true
                }
            }
        }
        .sheet(isPresented: $showingNewSchedule) {
            ScheduleEditorView()
        }
        .sheet(item: $editingSchedule) { schedule in
            ScheduleEditorView(schedule: schedule)
        }
        .confirmationDialog(
            "Delete Schedule?",
            isPresented: $showingDeleteConfirm,
            presenting: scheduleToDelete
        ) { schedule in
            Button("Delete", role: .destructive) {
                modelContext.delete(schedule)
            }
        } message: { schedule in
            Text("Delete schedule for \"\(schedule.profileName)\"?")
        }
        .overlay {
            if schedules.isEmpty {
                ContentUnavailableView(
                    "No Schedules",
                    systemImage: "calendar.badge.plus",
                    description: Text("Tap '+' to create a recurring schedule")
                )
            }
        }
    }

    private func scheduleRow(_ schedule: BlockSchedule) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.profileName)
                    .font(.headline)

                HStack(spacing: 4) {
                    ForEach(weekdayLabels(schedule.weekdays), id: \.self) { label in
                        Text(label)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2), in: Capsule())
                    }
                }

                Text(timeRangeText(schedule))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { schedule.isEnabled = $0 }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .opacity(schedule.isEnabled ? 1.0 : 0.5)
    }

    private func weekdayLabels(_ weekdays: [Int]) -> [String] {
        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return weekdays.sorted().compactMap { day in
            day >= 1 && day <= 7 ? names[day] : nil
        }
    }

    private func timeRangeText(_ schedule: BlockSchedule) -> String {
        let start = String(format: "%d:%02d %@",
            schedule.startHour % 12 == 0 ? 12 : schedule.startHour % 12,
            schedule.startMinute,
            schedule.startHour < 12 ? "AM" : "PM"
        )
        let end = String(format: "%d:%02d %@",
            schedule.endHour % 12 == 0 ? 12 : schedule.endHour % 12,
            schedule.endMinute,
            schedule.endHour < 12 ? "AM" : "PM"
        )
        return "\(start) – \(end)"
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Forge/Views/Schedules/ScheduleListView.swift
git commit -m "Add ScheduleListView with schedule cards, edit sheet, and delete confirmation"
```

---

### Task 5: Sidebar + ContentView Wiring

**Files:**
- Modify: `Forge/App/AppState.swift`
- Modify: `Forge/App/ContentView.swift`

- [ ] **Step 1: Add schedules to SidebarItem**

In `Forge/App/AppState.swift`, add `schedules` case to the `SidebarItem` enum. Read the file first.

Add after `case profiles = "Profiles"`:

```swift
    case schedules = "Schedules"
```

Add to the `icon` computed property:

```swift
        case .schedules: "calendar"
```

- [ ] **Step 2: Wire ScheduleListView in ContentView**

In `Forge/App/ContentView.swift`, add a case to the switch in the detail view. Read the file first.

Add after `case .profiles: ProfileListView()`:

```swift
            case .schedules:
                ScheduleListView()
```

- [ ] **Step 3: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Forge/App/AppState.swift Forge/App/ContentView.swift
git commit -m "Add Schedules to sidebar navigation"
```

---

### Task 6: ScheduleEvaluator Service

**Files:**
- Modify: `Forge/Services/ScheduleEvaluator.swift`
- Modify: `Forge/App/ForgeApp.swift`

- [ ] **Step 1: Read the current ScheduleEvaluator stub and ForgeApp**

Read: `Forge/Services/ScheduleEvaluator.swift`
Read: `Forge/App/ForgeApp.swift`

- [ ] **Step 2: Replace ScheduleEvaluator stub with timer-based implementation**

```swift
// Forge/Services/ScheduleEvaluator.swift
import Foundation
import SwiftData
import ForgeKit

@MainActor
final class ScheduleEvaluator {
    private var timer: Timer?
    private let pollInterval: TimeInterval = 30.0

    func start(appState: AppState, blockEngine: BlockEngine, modelContext: ModelContext) {
        stop()
        // Evaluate immediately on start
        evaluate(appState: appState, blockEngine: blockEngine, modelContext: modelContext)
        // Then poll every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self, weak appState, weak blockEngine] _ in
            Task { @MainActor in
                guard let self, let appState, let blockEngine else { return }
                self.evaluate(appState: appState, blockEngine: blockEngine, modelContext: modelContext)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func evaluate(appState: AppState, blockEngine: BlockEngine, modelContext: ModelContext) {
        // Don't start a new block if one is already active
        guard !appState.isBlockActive else { return }

        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        // Fetch enabled schedules
        let descriptor = FetchDescriptor<BlockSchedule>(
            predicate: #Predicate<BlockSchedule> { schedule in
                schedule.isEnabled
            }
        )
        guard let schedules = try? modelContext.fetch(descriptor) else { return }

        for schedule in schedules {
            let isActive = ScheduleMatch.isActive(
                weekday: weekday,
                hour: hour,
                minute: minute,
                scheduleWeekdays: schedule.weekdays,
                startHour: schedule.startHour,
                startMinute: schedule.startMinute,
                endHour: schedule.endHour,
                endMinute: schedule.endMinute
            )

            guard isActive else { continue }

            // Find the profile for this schedule
            let profileID = schedule.profileID
            let profileDescriptor = FetchDescriptor<BlockProfile>(
                predicate: #Predicate<BlockProfile> { profile in
                    profile.id == profileID
                }
            )
            guard let profile = try? modelContext.fetch(profileDescriptor).first else { continue }

            // Calculate remaining duration in the schedule window
            let endMinutes = schedule.endHour * 60 + schedule.endMinute
            let currentMinutes = hour * 60 + minute
            let remainingMinutes: Int
            if schedule.startHour < schedule.endHour || (schedule.startHour == schedule.endHour && schedule.startMinute < schedule.endMinute) {
                // Same-day
                remainingMinutes = endMinutes - currentMinutes
            } else {
                // Overnight
                if currentMinutes >= schedule.startHour * 60 + schedule.startMinute {
                    remainingMinutes = (24 * 60 - currentMinutes) + endMinutes
                } else {
                    remainingMinutes = endMinutes - currentMinutes
                }
            }

            let duration = TimeInterval(max(remainingMinutes, 1) * 60)

            Task {
                try? await blockEngine.startBlock(
                    profile: profile,
                    duration: duration,
                    dohServerIPs: [],
                    appState: appState,
                    modelContext: modelContext
                )
            }

            // Only start one block at a time
            break
        }
    }
}
```

- [ ] **Step 3: Wire ScheduleEvaluator into ForgeApp**

In `ForgeApp.swift`, add a property:

```swift
    @State private var scheduleEvaluator = ScheduleEvaluator()
```

In the `.task` modifier, after `bypassDetector.startMonitoring(appState: appState)`, the evaluator needs `modelContext`. Since we're in a `Scene` and not a `View`, we need to create the model context. Actually, the evaluator needs to be started from a view that has `@Environment(\.modelContext)`.

The simplest approach: add a `.task` in `ContentView` that starts the evaluator, since `ContentView` has access to `modelContext` via the environment.

In `Forge/App/ContentView.swift`, add after the `.frame(minWidth: 700, minHeight: 500)`:

```swift
        .task {
            let evaluator = ScheduleEvaluator()
            evaluator.start(
                appState: appState,
                blockEngine: blockEngine,
                modelContext: modelContext
            )
        }
```

Wait — this creates a new evaluator each time. Better approach: pass the evaluator via environment or store it on AppState.

Simplest: Add `@Environment(\.modelContext) private var modelContext` to `ContentView` and `@Environment(BlockEngine.self) private var blockEngine`, then start the evaluator in `.task`. Store the evaluator as `@State` in `ContentView`.

Read the actual files first to determine the best integration point.

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -scheme Forge -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Forge/Services/ScheduleEvaluator.swift Forge/App/ContentView.swift
git commit -m "Implement ScheduleEvaluator with 30s polling and wire into app lifecycle"
```

---

### Task 7: Run All Tests and Final Build Verification

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
Expected: All scheduling commits in order
