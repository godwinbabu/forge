import Foundation
import NetworkExtension

let xpcService = ExtensionXPCService.shared
let listener = NSXPCListener(machServiceName: "app.forge.Forge.ForgeFilterExtension")
listener.delegate = xpcService
listener.resume()

autoreleasepool {
    NEProvider.startSystemExtensionMode()
}
dispatchMain()
