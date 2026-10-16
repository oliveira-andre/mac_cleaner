import Foundation

/// A `.app` bundle discovered on disk, with the identifiers the leftovers
/// search keys off: display name + bundle id.
public struct InstalledApp: Sendable, Identifiable {
    public let url: URL
    public let name: String          // CFBundleName / file name (no .app)
    public let bundleID: String
    public let isSystem: Bool        // lives under /System or /Applications vs ~/Applications

    public var id: String { bundleID.isEmpty ? url.path : bundleID }

    public init(url: URL, name: String, bundleID: String, isSystem: Bool) {
        self.url = url
        self.name = name
        self.bundleID = bundleID
        self.isSystem = isSystem
    }
}

/// Where a leftover was found — used for grouping/display, matching CleanMyMac's
/// resource categories.
public enum LeftoverCategory: String, Sendable, CaseIterable {
    case binary            = "Application"
    case applicationSupport = "Application Support"
    case caches            = "Caches"
    case preferences       = "Preferences"
    case containers        = "Containers"
    case groupContainers   = "Group Containers"
    case logs              = "Logs"
    case savedState        = "Saved Application State"
    case cookies           = "Cookies"
    case httpStorages      = "HTTP Storages"
    case webKit            = "WebKit"
    case applicationScripts = "Application Scripts"
    case launchAgents      = "Launch Agents / Daemons"
    case crashReports      = "Crash Reports"
}

/// One file/directory belonging to an app, with its measured size.
public struct LeftoverItem: Sendable, Identifiable {
    public let url: URL
    public let category: LeftoverCategory
    public let sizeBytes: UInt64
    public var id: String { url.path }
}

/// Result of a deep-clean scan for one app.
public struct UninstallPlan: Sendable {
    public let app: InstalledApp
    public let items: [LeftoverItem]
    public var totalBytes: UInt64 { items.reduce(0) { $0 + $1.sizeBytes } }
}
