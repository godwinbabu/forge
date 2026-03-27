import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Forge")
                .font(.headline)
            Text("No active block")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
