import Foundation

/// A background/startup item. Covers launch agents & daemons (CleanMyMac's
/// `LaunchAgentModel` / `LaunchAgentsScanTask`); login items are a future add.
public struct StartupItem: Sendable, Identifiable {
    public enum Kind: String, Sendable { case launchAgent = "Launch Agent", launchDaemon = "Launch Daemon" }
    public enum Domain: String, Sendable { case user = "User", system = "System" }

    public let label: String
    public let programPath: String?
    public let plistURL: URL
    public let kind: Kind
    public let domain: Domain
    public let runAtLoad: Bool
    public let enabled: Bool

    public var id: String { plistURL.path }
    /// Removing a system-domain item needs the root helper.
    public var needsPrivilege: Bool { domain == .system }
}

/// A maintenance action, mirroring CleanMyMac's `MaintenanceTaskIdentifier`
/// runners (FreeUpRAM, FreeUpPurgeableSpace, PeriodicScripts,
/// RepairDiskPermissions). Root tasks route through the privileged helper;
/// user-level ones run directly.
public struct MaintenanceTask: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    public let requiresRoot: Bool
    public let command: [String]   // argv

    public static let catalog: [MaintenanceTask] = [
        .init(id: "launchservices", title: "Rebuild Launch Services",
              detail: "Fix duplicate/incorrect 'Open With' entries.",
              requiresRoot: false,
              command: ["/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                        "-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]),
        .init(id: "quicklook", title: "Reset Quick Look",
              detail: "Rebuild the Quick Look thumbnail cache.",
              requiresRoot: false, command: ["/usr/bin/qlmanage", "-r", "cache"]),
        .init(id: "flushdns", title: "Flush DNS Cache",
              detail: "Clear the system DNS resolver cache.",
              requiresRoot: true, command: ["/usr/bin/dscacheutil", "-flushcache"]),
        .init(id: "spotlight", title: "Reindex Spotlight",
              detail: "Rebuild the Spotlight index for all volumes.",
              requiresRoot: true, command: ["/usr/bin/mdutil", "-E", "/"]),
        .init(id: "freeram", title: "Free Up RAM",
              detail: "Purge inactive memory pages.",
              requiresRoot: true, command: ["/usr/sbin/purge"]),
    ]
}

public struct PerformanceReport: Sendable {
    public let startupItems: [StartupItem]
    public let memory: MemoryMetrics
}
