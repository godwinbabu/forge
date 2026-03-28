import SwiftUI

struct ScheduleListView: View {
    var body: some View {
        List {
            Text("No schedules")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Schedules")
    }
}
