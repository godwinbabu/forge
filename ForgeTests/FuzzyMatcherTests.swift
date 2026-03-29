import Testing
@testable import ForgeKit

@Suite("FuzzyMatcher Tests")
struct FuzzyMatcherTests {

    @Test func exactMatchScoresHighest() {
        let score = FuzzyMatcher.score(query: "settings", candidate: "Settings")
        #expect(score > 0)
    }

    @Test func prefixMatchScoresHigh() {
        let score1 = FuzzyMatcher.score(query: "set", candidate: "Settings")
        let score2 = FuzzyMatcher.score(query: "set", candidate: "Reset Options")
        #expect(score1 > score2)
    }

    @Test func noMatchReturnsZero() {
        let score = FuzzyMatcher.score(query: "xyz", candidate: "Settings")
        #expect(score == 0)
    }

    @Test func emptyQueryMatchesEverything() {
        let score = FuzzyMatcher.score(query: "", candidate: "Settings")
        #expect(score > 0)
    }

    @Test func caseInsensitive() {
        let score = FuzzyMatcher.score(query: "SET", candidate: "settings")
        #expect(score > 0)
    }

    @Test func matchSortsByScore() {
        let results = FuzzyMatcher.match(
            query: "pro",
            candidates: ["Profiles", "Import Profile", "Open Projects"]
        )
        #expect(results.first?.text == "Profiles")
    }

    @Test func nonMatchingCandidatesFiltered() {
        let results = FuzzyMatcher.match(
            query: "xyz",
            candidates: ["Profiles", "Settings", "Dashboard"]
        )
        #expect(results.isEmpty)
    }

    @Test func matchPreservesAllMatching() {
        let results = FuzzyMatcher.match(
            query: "s",
            candidates: ["Settings", "Schedules", "Dashboard"]
        )
        #expect(results.count == 3) // all contain 's'
    }
}
