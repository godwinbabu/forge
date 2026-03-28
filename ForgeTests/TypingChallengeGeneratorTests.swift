import Testing
@testable import ForgeKit

@Suite("TypingChallengeGenerator Tests")
struct TypingChallengeGeneratorTests {

    @Test func generatesTextWithinLengthBounds() {
        let generator = TypingChallengeGenerator()
        for _ in 0..<20 {
            let text = generator.generate(remainingTime: "1 hour 23 minutes")
            #expect(text.count >= 80, "Text too short: \(text.count) chars")
            #expect(text.count <= 120, "Text too long: \(text.count) chars")
        }
    }

    @Test func generatesUniqueTexts() {
        let generator = TypingChallengeGenerator()
        let texts = (0..<10).map { _ in generator.generate(remainingTime: "45 minutes") }
        let unique = Set(texts)
        #expect(unique.count > 1, "Should produce varied texts")
    }

    @Test func includesRemainingTimeInText() {
        let generator = TypingChallengeGenerator()
        let text = generator.generate(remainingTime: "2 hours 10 minutes")
        #expect(text.contains("2 hours 10 minutes"))
    }
}
