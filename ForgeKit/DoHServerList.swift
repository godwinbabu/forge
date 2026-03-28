import Foundation

public struct DoHServerList: Sendable {
    private var ips: Set<String>
    public var allIPs: Set<String> { ips }

    public init(jsonData: Data) throws {
        let decoded = try JSONDecoder().decode(DoHServerListJSON.self, from: jsonData)
        self.ips = Set(decoded.servers.flatMap(\.ips))
    }

    public func contains(ip: String) -> Bool { ips.contains(ip) }

    public mutating func addCustomIPs(_ newIPs: [String]) {
        ips.formUnion(newIPs)
    }
}

private struct DoHServerListJSON: Codable {
    let servers: [DoHServerEntry]
}

private struct DoHServerEntry: Codable {
    let name: String
    let ips: [String]
}
