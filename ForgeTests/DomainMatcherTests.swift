import Testing
@testable import ForgeKit

@Suite("DomainMatcher Tests")
struct DomainMatcherTests {

    @Test func exactMatchHitsExactDomain() {
        let matcher = DomainMatcher(rules: [.exact("reddit.com")])
        #expect(matcher.matches("reddit.com") == true)
    }

    @Test func exactMatchIsCaseInsensitive() {
        let matcher = DomainMatcher(rules: [.exact("Reddit.COM")])
        #expect(matcher.matches("reddit.com") == true)
    }

    @Test func exactMatchDoesNotMatchSubdomain() {
        let matcher = DomainMatcher(rules: [.exact("reddit.com")])
        #expect(matcher.matches("www.reddit.com") == false)
    }

    @Test func exactMatchDoesNotMatchUnrelatedDomain() {
        let matcher = DomainMatcher(rules: [.exact("reddit.com")])
        #expect(matcher.matches("google.com") == false)
    }

    @Test func wildcardMatchesSubdomain() {
        let matcher = DomainMatcher(rules: [.wildcard("*.reddit.com")])
        #expect(matcher.matches("www.reddit.com") == true)
        #expect(matcher.matches("old.reddit.com") == true)
        #expect(matcher.matches("m.reddit.com") == true)
    }

    @Test func wildcardMatchesDeepSubdomain() {
        let matcher = DomainMatcher(rules: [.wildcard("*.reddit.com")])
        #expect(matcher.matches("a.b.c.reddit.com") == true)
    }

    @Test func wildcardDoesNotMatchBaseDomain() {
        let matcher = DomainMatcher(rules: [.wildcard("*.reddit.com")])
        #expect(matcher.matches("reddit.com") == false)
    }

    @Test func wildcardDoesNotMatchUnrelatedDomain() {
        let matcher = DomainMatcher(rules: [.wildcard("*.reddit.com")])
        #expect(matcher.matches("www.google.com") == false)
    }

    @Test func portSpecificMatchesCorrectPort() {
        let matcher = DomainMatcher(rules: [.portSpecific("example.com", 8080)])
        #expect(matcher.matchesWithPort("example.com", port: 8080) == true)
    }

    @Test func portSpecificDoesNotMatchWrongPort() {
        let matcher = DomainMatcher(rules: [.portSpecific("example.com", 8080)])
        #expect(matcher.matchesWithPort("example.com", port: 443) == false)
    }

    @Test func multipleRulesMatchAny() {
        let matcher = DomainMatcher(rules: [
            .exact("reddit.com"),
            .wildcard("*.twitter.com"),
            .exact("facebook.com")
        ])
        #expect(matcher.matches("reddit.com") == true)
        #expect(matcher.matches("m.twitter.com") == true)
        #expect(matcher.matches("facebook.com") == true)
        #expect(matcher.matches("google.com") == false)
    }

    @Test func emptyRulesMatchNothing() {
        let matcher = DomainMatcher(rules: [])
        #expect(matcher.matches("anything.com") == false)
    }

    @Test func nilHostnameMatchesNothing() {
        let matcher = DomainMatcher(rules: [.exact("reddit.com")])
        #expect(matcher.matches(nil) == false)
    }
}
