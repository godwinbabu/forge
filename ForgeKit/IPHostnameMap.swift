import Foundation

public final class IPHostnameMap: @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func set(ip: String, hostname: String) {
        lock.withLock { storage[ip] = hostname }
    }

    public func hostname(for ip: String) -> String? {
        lock.withLock { storage[ip] }
    }

    public func clear() {
        lock.withLock { storage.removeAll() }
    }
}
