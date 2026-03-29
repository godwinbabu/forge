import SwiftUI

struct ProfileCardView: View {
    let profile: BlockProfile
    @Environment(AppState.self) private var appState
    @Environment(BlockEngine.self) private var blockEngine
    @Environment(\.modelContext) private var modelContext
    @State private var showingDuration = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: profile.iconName)
                    .font(.title2)
                    .foregroundStyle(
                        Color(hex: profile.colorHex) ?? .accentColor
                    )
                Spacer()
                Text(profile.isBlocklist ? "Blocklist" : "Allowlist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(profile.name)
                .font(.headline)

            Text("\(profile.domains.count) sites")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture { showingDuration = true }
        .sheet(isPresented: $showingDuration) {
            DurationPickerView(profile: profile)
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        guard hexString.count == 6,
              let int = UInt64(hexString, radix: 16) else {
            return nil
        }
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }

    var hexString: String {
        let resolved = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(resolved.redComponent * 255))
        let g = Int(round(resolved.greenComponent * 255))
        let b = Int(round(resolved.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
