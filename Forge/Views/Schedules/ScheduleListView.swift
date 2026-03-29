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
                    .onTapGesture { editingSchedule = schedule }
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
