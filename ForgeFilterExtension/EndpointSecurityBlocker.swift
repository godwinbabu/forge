// ForgeFilterExtension/EndpointSecurityBlocker.swift
import Foundation
import EndpointSecurity
import ForgeKit

final class EndpointSecurityBlocker: @unchecked Sendable {
    private var client: OpaquePointer? // es_client_t
    private let lock = NSLock()
    private var blockedBundleIDs = Set<String>()
    private var isSubscribed = false

    /// Create the ES client once. Call early in extension lifecycle.
    func createClient() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard client == nil else { return true }

        var newClient: OpaquePointer?
        let result = es_new_client(&newClient) { [weak self] _, event in
            self?.handleEvent(event)
        }

        guard result == ES_NEW_CLIENT_RESULT_SUCCESS, let newClient else {
            print("[ES] Failed to create client: \(result.rawValue)")
            return false
        }

        client = newClient
        return true
    }

    /// Activate blocking for the given bundle IDs.
    func activate(bundleIDs: Set<String>) {
        lock.lock()
        blockedBundleIDs = bundleIDs
        let currentClient = client
        let needsSubscribe = !isSubscribed
        lock.unlock()

        guard let currentClient else { return }

        // Clear mute cache so previously-muted processes are re-evaluated
        es_clear_cache(currentClient)

        if needsSubscribe {
            let events = [ES_EVENT_TYPE_AUTH_EXEC]
            let subResult = es_subscribe(currentClient, events, UInt32(events.count))
            if subResult == ES_RETURN_SUCCESS {
                lock.lock()
                isSubscribed = true
                lock.unlock()
            } else {
                print("[ES] Failed to subscribe: \(subResult.rawValue)")
            }
        }
    }

    /// Deactivate app blocking. Client stays alive.
    func deactivate() {
        lock.lock()
        blockedBundleIDs.removeAll()
        let currentClient = client
        let wasSubscribed = isSubscribed
        lock.unlock()

        guard let currentClient, wasSubscribed else { return }
        let events = [ES_EVENT_TYPE_AUTH_EXEC]
        es_unsubscribe(currentClient, events, UInt32(events.count))
        es_clear_cache(currentClient)

        lock.lock()
        isSubscribed = false
        lock.unlock()
    }

    /// Destroy the ES client. Call when extension stops.
    func destroyClient() {
        lock.lock()
        defer { lock.unlock() }
        guard let currentClient = client else { return }
        es_delete_client(currentClient)
        client = nil
        isSubscribed = false
        blockedBundleIDs.removeAll()
    }

    private func handleEvent(_ event: UnsafePointer<es_message_t>) {
        guard event.pointee.event_type == ES_EVENT_TYPE_AUTH_EXEC else { return }

        let execPath = String(
            cString: event.pointee.event.exec.target.pointee.executable.pointee.path.data
        )

        let bundleID = BundleIDResolver.bundleID(forExecutableAt: execPath)

        lock.lock()
        let blocked = blockedBundleIDs
        let currentClient = client
        lock.unlock()

        guard let currentClient else { return }

        // Protected apps: always allow
        if let bundleID, ProtectedApps.isProtected(bundleID) {
            es_respond_auth_result(currentClient, event, ES_AUTH_RESULT_ALLOW, false)
            return
        }

        // Check if blocked
        if let bundleID, blocked.contains(bundleID) {
            es_respond_auth_result(currentClient, event, ES_AUTH_RESULT_DENY, false)
            return
        }

        // Allow and mute for performance
        es_respond_auth_result(currentClient, event, ES_AUTH_RESULT_ALLOW, false)
        var auditToken = event.pointee.process.pointee.audit_token
        es_mute_process(currentClient, &auditToken)
    }
}
