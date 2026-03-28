import Testing
import Foundation
@testable import ForgeKit

@Suite("DoHServerList Tests")
struct DoHServerListTests {
    @Test func loadFromJSONData() throws {
        let json = Data("""
        { "servers": [
            { "name": "Cloudflare", "ips": ["1.1.1.1", "1.0.0.1"] },
            { "name": "Google", "ips": ["8.8.8.8", "8.8.4.4"] }
        ] }
        """.utf8)
        let list = try DoHServerList(jsonData: json)
        #expect(list.allIPs.count == 4)
        #expect(list.contains(ip: "1.1.1.1") == true)
        #expect(list.contains(ip: "8.8.4.4") == true)
    }

    @Test func doesNotContainRandomIP() throws {
        let json = Data("""
        { "servers": [{ "name": "Test", "ips": ["1.1.1.1"] }] }
        """.utf8)
        let list = try DoHServerList(jsonData: json)
        #expect(list.contains(ip: "192.168.1.1") == false)
    }

    @Test func emptyServersProducesEmptyList() throws {
        let json = Data("{ \"servers\": [] }".utf8)
        let list = try DoHServerList(jsonData: json)
        #expect(list.allIPs.isEmpty)
    }

    @Test func invalidJSONThrows() {
        let bad = Data("not json".utf8)
        #expect(throws: (any Error).self) { try DoHServerList(jsonData: bad) }
    }

    @Test func customIPsOverrideDefaults() throws {
        let json = Data("""
        { "servers": [{ "name": "Test", "ips": ["1.1.1.1"] }] }
        """.utf8)
        var list = try DoHServerList(jsonData: json)
        list.addCustomIPs(["9.9.9.9"])
        #expect(list.contains(ip: "9.9.9.9") == true)
        #expect(list.contains(ip: "1.1.1.1") == true)
    }
}
