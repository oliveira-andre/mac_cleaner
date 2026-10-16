import Foundation
import IPCProtocol

/// Client side of the privileged removal path. Connects to the root helper over
/// XPC and asks it to remove paths the current user can't (system-owned
/// leftovers). The helper validates our code-signing requirement before acting.
public struct PrivilegedFileRemover {
    public enum Failure: Error, CustomStringConvertible {
        case helperUnavailable(String)
        public var description: String {
            switch self {
            case .helperUnavailable(let m): return "privileged helper unavailable: \(m)"
            }
        }
    }

    public init() {}

    /// Synchronous remove via the helper. Returns removed paths + per-path errors.
    public func remove(paths: [String], timeout: TimeInterval = 30) throws
        -> (removed: [String], errors: [String: String]) {
        guard !paths.isEmpty else { return ([], [:]) }

        let conn = NSXPCConnection(machServiceName: IPC.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: PrivilegedRemoverProtocol.self)
        if #available(macOS 13.0, *) {
            conn.setCodeSigningRequirement(IPC.helperRequirement)
        }
        conn.resume()
        defer { conn.invalidate() }

        let sem = DispatchSemaphore(value: 0)
        var result: (removed: [String], errors: [String: String]) = ([], [:])
        var connError: String?

        let proxy = conn.remoteObjectProxyWithErrorHandler { err in
            connError = err.localizedDescription
            sem.signal()
        } as? PrivilegedRemoverProtocol

        guard let proxy else { throw Failure.helperUnavailable("no proxy") }
        proxy.removeItems(atPaths: paths) { removed, errors in
            result = (removed, errors)
            sem.signal()
        }

        if sem.wait(timeout: .now() + timeout) == .timedOut {
            throw Failure.helperUnavailable("timed out")
        }
        if let connError { throw Failure.helperUnavailable(connError) }
        return result
    }

    /// Whether the helper is reachable (registered + running).
    public func isHelperReachable(timeout: TimeInterval = 3) -> Bool {
        let conn = NSXPCConnection(machServiceName: IPC.machServiceName, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: PrivilegedRemoverProtocol.self)
        conn.resume()
        defer { conn.invalidate() }
        let sem = DispatchSemaphore(value: 0)
        var ok = false
        let proxy = conn.remoteObjectProxyWithErrorHandler { _ in sem.signal() } as? PrivilegedRemoverProtocol
        proxy?.helperVersion { _ in ok = true; sem.signal() }
        _ = sem.wait(timeout: .now() + timeout)
        return ok
    }
}
