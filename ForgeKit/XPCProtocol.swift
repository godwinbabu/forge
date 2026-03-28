import Foundation

@objc public protocol ForgeExtensionProtocol {
    func updateRuleset(_ rulesetData: Data, reply: @escaping (Error?) -> Void)
    func deactivateRuleset(reply: @escaping (Error?) -> Void)
    func getStatus(reply: @escaping (Data?) -> Void)
}

@objc public protocol ForgeAppCallbackProtocol {
    func flowBlocked(hostname: String, timestamp: Date)
}
