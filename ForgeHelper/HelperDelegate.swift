import Foundation

final class HelperDelegate: NSObject, ForgeHelperProtocol {
    func getVersion(reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }
}
