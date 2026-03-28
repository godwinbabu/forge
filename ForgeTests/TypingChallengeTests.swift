import Testing
@testable import ForgeKit

@Suite("TypingChallengeValidation Tests")
struct TypingChallengeValidationTests {

    @Test func correctInputAccepted() {
        var state = TypingChallengeState(targetText: "Hello world")
        state.userInput = "Hello world"
        #expect(state.isComplete)
        #expect(!state.hasError)
    }

    @Test func incorrectCharacterDetected() {
        var state = TypingChallengeState(targetText: "Hello world")
        state.userInput = "Hello x"
        #expect(state.hasError)
        #expect(!state.isComplete)
    }

    @Test func partialCorrectInputNotComplete() {
        var state = TypingChallengeState(targetText: "Hello world")
        state.userInput = "Hello"
        #expect(!state.isComplete)
        #expect(!state.hasError)
    }

    @Test func emptyInputIsValid() {
        var state = TypingChallengeState(targetText: "Hello world")
        state.userInput = ""
        #expect(!state.isComplete)
        #expect(!state.hasError)
    }

    @Test func progressCalculation() {
        var state = TypingChallengeState(targetText: "Hello world")
        state.userInput = "Hello"
        #expect(state.progress == 5.0 / 11.0)
    }

    @Test func resetClearsInput() {
        var state = TypingChallengeState(targetText: "Hello world")
        state.userInput = "Hello"
        state.reset(newTarget: "New text here")
        #expect(state.userInput.isEmpty)
        #expect(state.targetText == "New text here")
    }
}
