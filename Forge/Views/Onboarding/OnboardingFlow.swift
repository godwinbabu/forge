import SwiftUI

struct OnboardingFlow: View {
    var body: some View {
        VStack {
            Text("Welcome to Forge")
                .font(.largeTitle)
            Text("Forge your focus. Block distractions. No compromises.")
                .foregroundStyle(.secondary)
        }
        .frame(width: 500, height: 400)
    }
}
