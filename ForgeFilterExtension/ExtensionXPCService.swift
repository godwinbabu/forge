import Foundation
import ForgeKit

final class ExtensionXPCService: NSObject, NSXPCListenerDelegate, ForgeExtensionProtocol {
    nonisolated(unsafe) static let shared = ExtensionXPCService()

    private weak var filterProvider: FilterDataProvider?
    private weak var dnsProvider: DNSProxyProvider?

    override private init() {
        super.init()
    }

    func registerFilterProvider(_ provider: FilterDataProvider) {
        self.filterProvider = provider
    }

    func registerDNSProvider(_ provider: DNSProxyProvider) {
        self.dnsProvider = provider
    }

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: ForgeExtensionProtocol.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: ForgeAppCallbackProtocol.self)
        connection.resume()
        return true
    }

    func updateRuleset(_ rulesetData: Data, reply: @escaping (Error?) -> Void) {
        do {
            let ruleset = try JSONDecoder().decode(BlockRuleset.self, from: rulesetData)
            let store = RulesetStore(directory: containerURL())
            try store.save(ruleset)
            filterProvider?.applyRuleset(ruleset)
            dnsProvider?.applyRuleset(ruleset)
            reply(nil)
        } catch {
            reply(error)
        }
    }

    func deactivateRuleset(reply: @escaping (Error?) -> Void) {
        let store = RulesetStore(directory: containerURL())
        store.delete()
        filterProvider?.clearRuleset()
        dnsProvider?.clearRuleset()
        reply(nil)
    }

    func getStatus(reply: @escaping (Data?) -> Void) {
        let store = RulesetStore(directory: containerURL())
        guard let ruleset = store.loadIfActive() else { reply(nil); return }
        reply(try? JSONEncoder().encode(ruleset))
    }

    private func containerURL() -> URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.app.forge"
        ) ?? FileManager.default.temporaryDirectory
    }
}
