import Foundation

public struct CIDRMatcher: Sendable {
    private let ranges: [(network: UInt32, mask: UInt32)]

    public init(rules: [DomainRule]) {
        var parsed = [(UInt32, UInt32)]()
        for rule in rules {
            if case .cidr(let ip, let prefix) = rule {
                if let network = Self.parseIPv4(ip) {
                    let mask: UInt32 = prefix == 0 ? 0 : ~UInt32(0) << (32 - UInt32(prefix))
                    parsed.append((network & mask, mask))
                }
            }
        }
        self.ranges = parsed
    }

    public func matches(ip: String) -> Bool {
        guard let addr = Self.parseIPv4(ip) else { return false }
        return ranges.contains { addr & $0.mask == $0.network }
    }

    private static func parseIPv4(_ ip: String) -> UInt32? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var result: UInt32 = 0
        for part in parts {
            guard let octet = UInt32(part), octet <= 255 else { return nil }
            result = result << 8 | octet
        }
        return result
    }
}
