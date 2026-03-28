import Testing
import Foundation
@testable import ForgeKit

@Suite("CIDRMatcher Tests")
struct CIDRMatcherTests {
    @Test func ipv4InRange() {
        let matcher = CIDRMatcher(rules: [.cidr("192.168.1.0", 24)])
        #expect(matcher.matches(ip: "192.168.1.50") == true)
        #expect(matcher.matches(ip: "192.168.1.0") == true)
        #expect(matcher.matches(ip: "192.168.1.255") == true)
    }

    @Test func ipv4OutOfRange() {
        let matcher = CIDRMatcher(rules: [.cidr("192.168.1.0", 24)])
        #expect(matcher.matches(ip: "192.168.2.1") == false)
        #expect(matcher.matches(ip: "10.0.0.1") == false)
    }

    @Test func singleIPMatch() {
        let matcher = CIDRMatcher(rules: [.cidr("1.1.1.1", 32)])
        #expect(matcher.matches(ip: "1.1.1.1") == true)
        #expect(matcher.matches(ip: "1.1.1.2") == false)
    }

    @Test func wideRange() {
        let matcher = CIDRMatcher(rules: [.cidr("10.0.0.0", 8)])
        #expect(matcher.matches(ip: "10.255.255.255") == true)
        #expect(matcher.matches(ip: "11.0.0.0") == false)
    }

    @Test func multipleRanges() {
        let matcher = CIDRMatcher(rules: [.cidr("192.168.1.0", 24), .cidr("10.0.0.0", 8)])
        #expect(matcher.matches(ip: "192.168.1.5") == true)
        #expect(matcher.matches(ip: "10.1.2.3") == true)
        #expect(matcher.matches(ip: "172.16.0.1") == false)
    }

    @Test func invalidIPReturnsNoMatch() {
        let matcher = CIDRMatcher(rules: [.cidr("192.168.1.0", 24)])
        #expect(matcher.matches(ip: "not-an-ip") == false)
        #expect(matcher.matches(ip: "") == false)
    }

    @Test func emptyRulesMatchNothing() {
        let matcher = CIDRMatcher(rules: [])
        #expect(matcher.matches(ip: "1.1.1.1") == false)
    }
}
