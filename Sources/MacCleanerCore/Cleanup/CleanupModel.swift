import Foundation

/// Categories of removable junk. Mirrors CleanMyMac's System Junk / Trash /
/// caches surface (JunkCleanupModule → SystemJunkScanning + TrashJunkScanning).
public enum JunkCategory: String, Sendable, CaseIterable {
    case userCaches         = "User Caches"
    case userLogs           = "User Logs"
    case savedState         = "Saved Application State"
    case trash              = "Trash"
    case xcodeDerivedData   = "Xcode Derived Data"
    case xcodeArchives      = "Xcode Archives"
    case xcodeDeviceSupport = "Xcode Device Support"

    /// Whether CleanMyMac's `JunkCleanupAutoSelectableStrategy` would pre-tick
    /// it. Cache/log/derived-data regenerate and are safe to auto-select; saved
    /// state is left for the user to opt into.
    public var autoSelect: Bool {
        self != .savedState
    }
}

public struct JunkItem: Sendable, Identifiable {
    public let url: URL
    public let category: JunkCategory
    public let sizeBytes: UInt64
    public var id: String { url.path }
}

public struct CleanupReport: Sendable {
    public let items: [JunkItem]
    public var totalBytes: UInt64 { items.reduce(0) { $0 + $1.sizeBytes } }
    public var autoSelectedBytes: UInt64 {
        items.filter { $0.category.autoSelect }.reduce(0) { $0 + $1.sizeBytes }
    }
}
