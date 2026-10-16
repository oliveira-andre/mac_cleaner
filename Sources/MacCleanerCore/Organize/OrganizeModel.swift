import Foundation

/// A large and/or old file (CleanMyMac's "LAOF" kind under OrganizeModule).
public struct LargeOldFile: Sendable, Identifiable {
    public let url: URL
    public let sizeBytes: UInt64
    public let lastUsed: Date
    public var id: String { url.path }

    public var ageDays: Int {
        max(0, Calendar.current.dateComponents([.day], from: lastUsed, to: Date()).day ?? 0)
    }
}

/// A set of byte-for-byte identical files (the exact-duplicate core of the
/// "Gemini Duplicates" engine). Keeping one copy frees `reclaimableBytes`.
public struct DuplicateGroup: Sendable, Identifiable {
    public let contentHash: String
    public let urls: [URL]
    public let sizeEach: UInt64
    public var id: String { contentHash }
    public var count: Int { urls.count }
    public var reclaimableBytes: UInt64 { sizeEach * UInt64(max(0, count - 1)) }

    /// The copy to keep (shortest path — usually the "original" location);
    /// the rest are the removable duplicates.
    public var keeper: URL { urls.min { $0.path.count < $1.path.count } ?? urls[0] }
    public var removableDuplicates: [URL] { urls.filter { $0 != keeper } }
}

public struct ClutterReport: Sendable {
    public let largeOldFiles: [LargeOldFile]
    public let duplicateGroups: [DuplicateGroup]

    public var largeOldBytes: UInt64 { largeOldFiles.reduce(0) { $0 + $1.sizeBytes } }
    public var duplicateReclaimableBytes: UInt64 { duplicateGroups.reduce(0) { $0 + $1.reclaimableBytes } }
}
