import Foundation
import IPCProtocol

/// The root-side implementation. Performs the actual privileged removals.
/// Shared by the real launchd listener and the in-process self-test.
final class HelperService: NSObject, PrivilegedRemoverProtocol {
    func removeItems(atPaths paths: [String],
                     withReply reply: @escaping ([String], [String: String]) -> Void) {
        let fm = FileManager.default
        var removed: [String] = []
        var errors: [String: String] = [:]
        for path in paths {
            // Refuse obviously dangerous roots as a guardrail.
            guard Self.isSafeToRemove(path) else {
                errors[path] = "refused: path not permitted"
                continue
            }
            do {
                try fm.removeItem(atPath: path)
                removed.append(path)
            } catch {
                errors[path] = error.localizedDescription
            }
        }
        reply(removed, errors)
    }

    func helperVersion(withReply reply: @escaping (String) -> Void) {
        reply(kHelperVersion)
    }

    /// Minimal denylist so a bug or a bad caller can't ask root to wipe the
    /// system. A production helper would also validate against the originating
    /// uninstall plan.
    static func isSafeToRemove(_ path: String) -> Bool {
        let normalized = (path as NSString).standardizingPath
        let forbidden = ["/", "/System", "/usr", "/bin", "/sbin", "/etc",
                         "/var", "/Library", "/Applications", "/private"]
        if forbidden.contains(normalized) { return false }
        if !normalized.hasPrefix("/") { return false }
        return true
    }
}

/// NSXPCListener delegate that pins the caller to the expected code-signing
/// requirement before exposing the interface — CleanMyMac's `XPCCredentials` /
/// `AuthorizationRule` gate, done with the modern macOS 13 API.
final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let service = HelperService()
    private let enforceRequirement: Bool

    init(enforceRequirement: Bool = true) {
        self.enforceRequirement = enforceRequirement
    }

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        if enforceRequirement, #available(macOS 13.0, *) {
            newConnection.setCodeSigningRequirement(IPC.clientRequirement)
        }
        newConnection.exportedInterface = NSXPCInterface(with: PrivilegedRemoverProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}
