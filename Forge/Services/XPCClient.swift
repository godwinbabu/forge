import Foundation

final class XPCClient: Sendable {
    static let shared = XPCClient()

    private init() {}
}
