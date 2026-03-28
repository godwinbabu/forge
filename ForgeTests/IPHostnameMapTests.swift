import Testing
import Foundation
@testable import ForgeKit

@Suite("IPHostnameMap Tests")
struct IPHostnameMapTests {
    @Test func setAndLookup() {
        let map = IPHostnameMap()
        map.set(ip: "93.184.216.34", hostname: "example.com")
        #expect(map.hostname(for: "93.184.216.34") == "example.com")
    }

    @Test func lookupMissingIPReturnsNil() {
        let map = IPHostnameMap()
        #expect(map.hostname(for: "1.2.3.4") == nil)
    }

    @Test func overwriteExistingIP() {
        let map = IPHostnameMap()
        map.set(ip: "1.1.1.1", hostname: "old.com")
        map.set(ip: "1.1.1.1", hostname: "new.com")
        #expect(map.hostname(for: "1.1.1.1") == "new.com")
    }

    @Test func clearRemovesAll() {
        let map = IPHostnameMap()
        map.set(ip: "1.1.1.1", hostname: "a.com")
        map.set(ip: "2.2.2.2", hostname: "b.com")
        map.clear()
        #expect(map.hostname(for: "1.1.1.1") == nil)
        #expect(map.hostname(for: "2.2.2.2") == nil)
    }

    @Test func concurrentAccessIsSafe() async {
        let map = IPHostnameMap()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask { map.set(ip: "10.0.0.\(i % 256)", hostname: "host\(i).com") }
                group.addTask { _ = map.hostname(for: "10.0.0.\(i % 256)") }
            }
        }
        #expect(true) // No crash = safe
    }
}
