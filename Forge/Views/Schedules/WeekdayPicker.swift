import SwiftUI

struct WeekdayPicker: View {
    @Binding var selectedWeekdays: [Int]

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
                                ? Color.accentColor : Color.secondary.opacity(0.2),
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
