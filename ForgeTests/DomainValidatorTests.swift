import Testing
@testable import ForgeKit

@Suite("DomainValidator Tests")
struct DomainValidatorTests {

    @Test func acceptsValidDomain() {
        let result = DomainValidator.validate("reddit.com")
        #expect(result == "reddit.com")
    }

    @Test func lowercasesAndTrims() {
        let result = DomainValidator.validate("  Reddit.COM  ")
        #expect(result == "reddit.com")
    }

    @Test func rejectsNoDot() {
        let result = DomainValidator.validate("reddit")
        #expect(result == nil)
    }

    @Test func rejectsEmpty() {
        let result = DomainValidator.validate("")
        #expect(result == nil)
    }

    @Test func rejectsWhitespaceOnly() {
        let result = DomainValidator.validate("   ")
        #expect(result == nil)
    }

    @Test func validateListDeduplicates() {
        let result = DomainValidator.validateList([
            "reddit.com", "Reddit.COM", "twitter.com", "reddit.com"
        ])
        #expect(result == ["reddit.com", "twitter.com"])
    }

    @Test func validateListFiltersInvalid() {
        let result = DomainValidator.validateList([
            "reddit.com", "invalid", "", "twitter.com"
        ])
        #expect(result == ["reddit.com", "twitter.com"])
    }
}
