import Foundation

public struct FuzzyMatch: Sendable {
    public let text: String
    public let score: Int
}

public enum FuzzyMatcher {
    /// Returns matches sorted by score (highest first).
    /// Filters out candidates that don't match the query.
    public static func match(query: String, candidates: [String]) -> [FuzzyMatch] {
        candidates.compactMap { candidate in
            let s = score(query: query, candidate: candidate)
            return s > 0 ? FuzzyMatch(text: candidate, score: s) : nil
        }
        .sorted { $0.score > $1.score }
    }

    /// Check if query characters appear in candidate in order (case-insensitive).
    /// Returns score > 0 if matched, 0 if no match.
    public static func score(query: String, candidate: String) -> Int {
        if query.isEmpty { return 1 }

        let queryChars = Array(query)
        let candidateChars = Array(candidate)
        let queryLower = Array(query.lowercased())
        let candidateLower = Array(candidate.lowercased())

        var totalScore = 0
        var candidateIdx = 0
        var previousMatchIdx = -2 // impossible adjacent value

        for qi in 0..<queryLower.count {
            var found = false
            while candidateIdx < candidateLower.count {
                if candidateLower[candidateIdx] == queryLower[qi] {
                    // Base point
                    totalScore += 1

                    // Consecutive match bonus
                    if candidateIdx == previousMatchIdx + 1 && qi > 0 {
                        totalScore += 2
                    }

                    // Word start bonus
                    if candidateIdx == 0 || candidateChars[candidateIdx - 1] == " " {
                        totalScore += 5
                    }

                    // Case-exact match bonus
                    if candidateChars[candidateIdx] == queryChars[qi] {
                        totalScore += 1
                    }

                    previousMatchIdx = candidateIdx
                    candidateIdx += 1
                    found = true
                    break
                }
                candidateIdx += 1
            }
            if !found { return 0 }
        }

        return totalScore
    }
}
