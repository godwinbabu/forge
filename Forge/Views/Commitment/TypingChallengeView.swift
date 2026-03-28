import SwiftUI
import UniformTypeIdentifiers
import ForgeKit

struct TypingChallengeView: View {
    let remainingTime: String
    let onCompleted: () -> Void
    let onCancel: () -> Void

    @State private var challengeState: TypingChallengeState
    @State private var errorFlash = false
    @FocusState private var isInputFocused: Bool

    private let generator = TypingChallengeGenerator()

    init(remainingTime: String, onCompleted: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.remainingTime = remainingTime
        self.onCompleted = onCompleted
        self.onCancel = onCancel
        let generator = TypingChallengeGenerator()
        _challengeState = State(initialValue: TypingChallengeState(
            targetText: generator.generate(remainingTime: remainingTime)
        ))
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Type the following to confirm")
                .font(.title2.bold())

            Text(challengeState.targetText)
                .font(.system(.body, design: .monospaced))
                .padding(16)
                .frame(maxWidth: 500)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                TextField("Type here...", text: $challengeState.userInput)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 500)
                    .focused($isInputFocused)
                    .autocorrectionDisabled()
                    .onPasteCommand(of: [UTType]()) { _ in }
                    .onChange(of: challengeState.userInput) {
                        if challengeState.hasError {
                            errorFlash = true
                            let newTarget = generator.generate(remainingTime: remainingTime)
                            challengeState.reset(newTarget: newTarget)
                            Task {
                                try? await Task.sleep(for: .milliseconds(300))
                                errorFlash = false
                            }
                        }
                        if challengeState.isComplete {
                            onCompleted()
                        }
                    }

                if errorFlash {
                    Text("Typo — text has been reset")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                ProgressView(value: challengeState.progress)
                    .frame(maxWidth: 500)
                    .tint(errorFlash ? .red : .blue)
            }

            Button("Cancel — continue my session", role: .cancel) {
                onCancel()
            }
            .font(.callout)

            Spacer()
        }
        .padding(48)
        .animation(.easeInOut(duration: 0.15), value: errorFlash)
        .onAppear { isInputFocused = true }
    }
}
