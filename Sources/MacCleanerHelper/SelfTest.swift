import Foundation
import IPCProtocol

/// In-process verification of the XPC wiring and removal logic. Uses an
/// anonymous listener (no Mach service, no launchd, no root) and operates only
/// on a throwaway temp file. The code-signing-requirement check can't be
/// exercised here (that needs two separately signed processes), so it's
/// disabled for the self-test only.
enum SelfTest {
    static func run() {
        let delegate = HelperListenerDelegate(enforceRequirement: false)
        let listener = NSXPCListener.anonymous()
        listener.delegate = delegate
        listener.resume()

        // Create a temp file for the "privileged" removal to target.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("maccleaner-selftest-\(UUID().uuidString).tmp")
        FileManager.default.createFile(atPath: tmp.path, contents: Data("x".utf8))
        let existedBefore = FileManager.default.fileExists(atPath: tmp.path)

        let conn = NSXPCConnection(listenerEndpoint: listener.endpoint)
        conn.remoteObjectInterface = NSXPCInterface(with: PrivilegedRemoverProtocol.self)
        conn.resume()

        let sem = DispatchSemaphore(value: 0)
        var version = "?"
        var removed: [String] = []
        var errors: [String: String] = [:]

        let proxy = conn.remoteObjectProxyWithErrorHandler { err in
            print("XPC error: \(err.localizedDescription)")
            sem.signal()
        } as? PrivilegedRemoverProtocol

        proxy?.helperVersion { v in
            version = v
            proxy?.removeItems(atPaths: [tmp.path]) { r, e in
                removed = r; errors = e; sem.signal()
            }
        }

        _ = sem.wait(timeout: .now() + 5)
        let existsAfter = FileManager.default.fileExists(atPath: tmp.path)
        conn.invalidate()

        print("helper version:  \(version)")
        print("target existed:  \(existedBefore)")
        print("removed:         \(removed)")
        print("errors:          \(errors)")
        print("target gone now: \(!existsAfter)")
        print(version == kHelperVersion && !existsAfter && removed == [tmp.path]
              ? "SELFTEST: PASS" : "SELFTEST: FAIL")
    }
}
