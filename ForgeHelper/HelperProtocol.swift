import Foundation

@objc protocol ForgeHelperProtocol {
    func getVersion(reply: @escaping (String) -> Void)
}
