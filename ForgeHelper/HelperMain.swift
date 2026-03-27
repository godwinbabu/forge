import Foundation

@main
enum HelperApp {
    static func main() {
        let delegate = HelperConnectionDelegate()
        let listener = NSXPCListener(machServiceName: "app.forge.helper")
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}

final class HelperConnectionDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: ForgeHelperProtocol.self)
        newConnection.exportedObject = HelperDelegate()
        newConnection.resume()
        return true
    }
}
