import Foundation
import ForgeKit

final class ExtensionXPCClient: @unchecked Sendable {
    private let machServiceName = "app.forge.Forge.ForgeFilterExtension"
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    private func getConnection() -> NSXPCConnection {
        lock.withLock {
            if let existing = connection { return existing }
            let conn = NSXPCConnection(
                machServiceName: machServiceName,
                options: .privileged
            )
            conn.remoteObjectInterface = NSXPCInterface(
                with: ForgeExtensionProtocol.self
            )
            conn.invalidationHandler = { [weak self] in
                guard let self else { return }
                self.lock.withLock { self.connection = nil }
            }
            conn.resume()
            connection = conn
            return conn
        }
    }

    private func proxy() throws -> any ForgeExtensionProtocol {
        guard let proxy = getConnection().remoteObjectProxy as? any ForgeExtensionProtocol else {
            throw NSError(domain: "ForgeXPC", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create XPC proxy"
            ])
        }
        return proxy
    }

    func updateRuleset(_ ruleset: BlockRuleset) async throws {
        let data = try JSONEncoder().encode(ruleset)
        let remoteProxy = try proxy()
        return try await withCheckedThrowingContinuation { continuation in
            remoteProxy.updateRuleset(data) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func deactivateRuleset() async throws {
        let remoteProxy = try proxy()
        return try await withCheckedThrowingContinuation { continuation in
            remoteProxy.deactivateRuleset { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func getStatus() async -> BlockRuleset? {
        guard let remoteProxy = try? proxy() else { return nil }
        return await withCheckedContinuation { continuation in
            remoteProxy.getStatus { data in
                guard let data else { continuation.resume(returning: nil); return }
                continuation.resume(
                    returning: try? JSONDecoder().decode(BlockRuleset.self, from: data)
                )
            }
        }
    }
}
