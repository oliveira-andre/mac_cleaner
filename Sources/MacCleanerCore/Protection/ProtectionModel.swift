import Foundation

// MARK: - Privacy

/// A removable privacy artifact (browser data or recent-items list). CleanMyMac
/// edits these at the DB-row level; this MVP works at the file level.
public struct PrivacyItem: Sendable, Identifiable {
    public let browser: String          // "Safari", "Chrome", "Firefox", …
    public let category: String         // "History", "Cookies", "Cache", …
    public let url: URL
    public let sizeBytes: UInt64
    public var id: String { url.path }
}

public struct PrivacyReport: Sendable {
    public let items: [PrivacyItem]
    public var totalBytes: UInt64 { items.reduce(0) { $0 + $1.sizeBytes } }
}

// MARK: - Malware

/// The rule kinds Moonlock uses (subset): match by path, by launch-agent
/// label, or by signing Team ID. The real app pulls a live-updated rule
/// database (`MalwareDatabaseService`); this ships a small static starter set.
public enum MalwareRuleKind: String, Sendable {
    case path          // a file/bundle exists at this path (globs with *)
    case launchAgent   // a launch agent/daemon with this Label exists
    case teamID        // an app signed by this (known-bad) Team ID
}

public struct MalwareRule: Sendable, Identifiable {
    public let id: String
    public let threatName: String
    public let kind: MalwareRuleKind
    public let value: String
    public init(_ id: String, _ threatName: String, _ kind: MalwareRuleKind, _ value: String) {
        self.id = id; self.threatName = threatName; self.kind = kind; self.value = value
    }

    /// Minimal starter set of well-known macOS adware/PUP indicators (public
    /// knowledge). NOT a substitute for a live threat database.
    public static let starterSet: [MalwareRule] = [
        .init("genieo-la",   "Genieo",                .launchAgent, "com.genieo."),
        .init("genieo-path", "Genieo",                .path,        "~/Library/Application Support/com.genieoinnovation.Installer"),
        .init("vsearch-la",  "VSearch/Conduit",       .launchAgent, "com.vsearch."),
        .init("mackeeper",   "MacKeeper",             .path,        "/Applications/MacKeeper.app"),
        .init("amc",         "Advanced Mac Cleaner",  .path,        "/Applications/Advanced Mac Cleaner.app"),
        .init("mackeeper-la","MacKeeper",             .launchAgent, "com.mackeeper."),
        .init("pirrit-la",   "Pirrit",                .launchAgent, "com.pirrit."),
        .init("bundlore-la", "Bundlore/Adload",       .launchAgent, "com.bundlore."),
        .init("spigot-la",   "Spigot",                .launchAgent, "com.spigot."),
        .init("pcv-la",      "Advanced Mac Cleaner",  .launchAgent, "com.pcv.hlpramc"),
        .init("pplauncher",  "Pirrit (pplauncher)",   .launchAgent, "com.pplauncher"),
        .init("mmp-la",      "MyMacProtector",        .launchAgent, "com.MyMacProtector."),
    ]
}

public struct MalwareFinding: Sendable, Identifiable {
    public let rule: MalwareRule
    public let matchedPath: String
    public var id: String { rule.id + ":" + matchedPath }
    public var threatName: String { rule.threatName }
}
