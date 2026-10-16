import Foundation

/// Aggregated result of a Smart Care pass. Mirrors `SmartCareModuleScanResult`:
/// the orchestrator runs every scanning module and composes their findings
/// into cards. Safe-to-automate areas (junk, privacy, malware) are auto-run;
/// judgment-call areas (clutter, startup items) are surfaced for review.
public struct SmartCareReport: Sendable {
    public let cleanup: CleanupReport
    public let privacy: PrivacyReport
    public let malware: [MalwareFinding]
    public let clutter: ClutterReport
    public let startupCount: Int

    /// What "Run Smart Care" will reclaim automatically.
    public var autoReclaimBytes: UInt64 { cleanup.autoSelectedBytes + privacy.totalBytes }
    public var threatCount: Int { malware.count }
    /// Surfaced-for-review totals (not auto-run).
    public var duplicateReclaimBytes: UInt64 { clutter.duplicateReclaimableBytes }
    public var largeOldBytes: UInt64 { clutter.largeOldBytes }
}

/// Runs every scanning module and composes the report.
public struct SmartCareScanner {
    public init() {}

    public func scan(includeClutter: Bool = true) -> SmartCareReport {
        let cleanup = CleanupScanner().scan()
        let privacy = PrivacyScanner().scan()
        let startup = PerformanceScanner().scanStartupItems()
        let malware = MalwareScanner().scan(startupItems: startup)
        let clutter = includeClutter ? OrganizeScanner().scan()
                                     : ClutterReport(largeOldFiles: [], duplicateGroups: [])
        return SmartCareReport(cleanup: cleanup, privacy: privacy, malware: malware,
                               clutter: clutter, startupCount: startup.count)
    }
}

/// Executes the auto-run portion of a Smart Care pass.
public struct SmartCareRunner {
    public struct Summary: Sendable {
        public let freedCount: Int
        public let threatsRemoved: Int
        public let needsPrivilege: Int
    }

    public init() {}

    public func runAuto(_ report: SmartCareReport) -> Summary {
        let remover = FileRemover()

        // Junk (auto-selected categories) + all privacy items.
        let junk = report.cleanup.items.filter { $0.category.autoSelect }.map(\.url)
        let privacy = report.privacy.items.map(\.url)
        let cleanOutcome = remover.moveToTrash(urls: junk + privacy)

        // Malware: quarantine matched paths.
        let malwarePaths = report.malware.map { URL(fileURLWithPath: $0.matchedPath) }
        let malwareOutcome = remover.moveToTrash(urls: malwarePaths)

        return Summary(
            freedCount: cleanOutcome.trashed.count + malwareOutcome.trashed.count,
            threatsRemoved: malwareOutcome.trashed.count,
            needsPrivilege: cleanOutcome.needsPrivilege.count + malwareOutcome.needsPrivilege.count
        )
    }
}
