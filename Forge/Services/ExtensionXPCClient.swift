import Foundation
import ForgeKit

final class ExtensionXPCClient: Sendable {
    private let machServiceName = "app.forge.Forge.ForgeFilterExtension"

    func updateRuleset(_ ruleset: BlockRuleset) async throws {
        let data = try JSONEncoder().encode(ruleset)
        let proxy = try proxy()
        return try await withCheckedThrowingContinuation { continuation in
            proxy.updateRuleset(data) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func deactivateRuleset() async throws {
        let proxy = try proxy()
        return try await withCheckedThrowingContinuation { continuation in
            proxy.deactivateRuleset { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func getStatus() async -> BlockRuleset? {
        guard let proxy = try? proxy() else { return nil }
        return await withCheckedContinuation { continuation in
            proxy.getStatus { data in
                guard let data else { continuation.resume(returning: nil); return }
                continuation.resume(
                    returning: try? JSONDecoder().decode(BlockRuleset.self, from: data)
                )
            }
        }
    }

    private func proxy() throws -> any ForgeExtensionProtocol {
        let connection = NSXPCConnection(
            machServiceName: machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(
            with: ForgeExtensionProtocol.self
        )
        connection.resume()
        guard let proxy = connection.remoteObjectProxy as? any ForgeExtensionProtocol else {
            throw NSError(domain: "ForgeXPC", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create XPC proxy"
            ])
        }
        return proxy
    }
}
