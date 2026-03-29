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
