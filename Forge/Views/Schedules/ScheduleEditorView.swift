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
