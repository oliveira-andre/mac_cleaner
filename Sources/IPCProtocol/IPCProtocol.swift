import Foundation

/// Shared contract between the unprivileged app and the root helper.
/// Mirrors CleanMyMac's `IPCProtocol` framework: a small, typed XPC surface
/// whose server validates the caller's code-signing requirement.
///
/// Identifiers are deliberately fixed — the Mach service name and the signing
/// requirements must stay stable once the helper is installed, or clients can
/// no longer reach (or be trusted by) the daemon.
public enum IPC {
    /// Keep this stable forever once shipped.
    public static let machServiceName = "io.partnerfleet.maccleaner.helper"

    /// Your Developer ID Team ID. Fill in before signing/installing; both the
    /// helper (checking clients) and the client (checking the helper) pin it.
    public static let teamIdentifier = "CHANGEME_TEAMID"

    /// Requirement the HELPER enforces on connecting clients.
    public static var clientRequirement: String {
        #"anchor apple generic and certificate leaf[subject.OU] = "\#(teamIdentifier)""#
    }

    /// Requirement the CLIENT enforces on the helper it connects to.
    public static var helperRequirement: String {
        #"anchor apple generic and certificate leaf[subject.OU] = "\#(teamIdentifier)""#
    }
}

/// The privileged operations the root helper exposes. Intentionally narrow —
/// each is a specific, auditable action, as in CleanMyMac's
/// `PrivilegedOperationsPerformerService` request catalog.
@objc public protocol PrivilegedRemoverProtocol {
    /// Remove the given filesystem paths as root. Replies with the paths that
    /// were removed and a map of path → error message for any that failed.
    func removeItems(atPaths paths: [String],
                     withReply reply: @escaping ([String], [String: String]) -> Void)

    /// Liveness/version probe.
    func helperVersion(withReply reply: @escaping (String) -> Void)
}

public let kHelperVersion = "0.1.0"
