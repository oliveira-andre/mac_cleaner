import Foundation
import MacCleanerCore

// Usage:
//   MacCleanerUninstall                 list installed apps
//   MacCleanerUninstall --app "Name"    deep-clean scan for one app (dry run)
//   MacCleanerUninstall --app "Name" --trash   move its leftovers to Trash
//
// Dry run is the default; nothing is deleted without --trash.

let args = CommandLine.arguments
let scanner = AppScanner()

func bytes(_ b: UInt64) -> String {
    let f = ByteCountFormatter(); f.countStyle = .file
    return f.string(fromByteCount: Int64(b))
}

// `--smart-care` runs the full orchestrated scan (read-only summary).
if args.contains("--smart-care") {
    let r = SmartCareScanner().scan(includeClutter: !args.contains("--no-clutter"))
    print("Smart Care scan:\n")
    print("  Cleanup (junk):    \(bytes(r.cleanup.autoSelectedBytes))  [auto]")
    print("  Privacy:           \(bytes(r.privacy.totalBytes)) across \(r.privacy.items.count) items  [auto]")
    print("  Protection:        \(r.threatCount == 0 ? "clean" : "\(r.threatCount) threats")  [auto]")
    print("  Performance:       \(r.startupCount) startup items  [review]")
    print("  Duplicates:        \(bytes(r.duplicateReclaimBytes))  [review]")
    print("  Large & Old:       \(bytes(r.largeOldBytes))  [review]")
    print("\n  → Auto-clean total: \(bytes(r.autoReclaimBytes))")
    exit(0)
}

// `--scan-protection` verifies the Protection privacy + malware scan (read-only).
if args.contains("--scan-protection") {
    let privacy = PrivacyScanner().scan()
    print("Privacy — \(privacy.items.count) items, \(bytes(privacy.totalBytes)):")
    for item in privacy.items { print("  \(bytes(item.sizeBytes))  \(item.browser) — \(item.category)") }
    let findings = MalwareScanner().scan()
    print("\nMalware (starter rule set) — \(findings.count) finding(s):")
    if findings.isEmpty { print("  clean") }
    for f in findings { print("  [\(f.threatName)] \(f.matchedPath)") }
    exit(0)
}

// `--scan-startup` verifies the Performance startup-items scanner (read-only).
if args.contains("--scan-startup") {
    let report = PerformanceScanner().scan()
    print("Startup items — \(report.startupItems.count):\n")
    for item in report.startupItems {
        let flags = [item.runAtLoad ? "at-login" : nil, item.enabled ? nil : "disabled"].compactMap { $0 }.joined(separator: ",")
        print("  [\(item.kind.rawValue.prefix(1))/\(item.domain.rawValue.prefix(1))] \(item.label)\(flags.isEmpty ? "" : "  (\(flags))")")
    }
    print("\nMaintenance tasks: \(MaintenanceTask.catalog.map { "\($0.title)\($0.requiresRoot ? "*" : "")" }.joined(separator: ", "))  (* = needs root)")
    exit(0)
}

// `--scan-clutter [--root <path>]` verifies the My Clutter scanner (read-only).
if args.contains("--scan-clutter") {
    var roots: [URL]? = nil
    if let i = args.firstIndex(of: "--root"), i + 1 < args.count {
        roots = [URL(fileURLWithPath: (args[i + 1] as NSString).expandingTildeInPath)]
    }
    let report = OrganizeScanner(roots: roots).scan()
    print("Large & Old Files — \(report.largeOldFiles.count) files, \(bytes(report.largeOldBytes)):")
    for f in report.largeOldFiles.prefix(10) {
        print("  \(bytes(f.sizeBytes))  \(f.ageDays)d  \(f.url.path)")
    }
    print("\nDuplicates — \(report.duplicateGroups.count) groups, \(bytes(report.duplicateReclaimableBytes)) reclaimable:")
    for g in report.duplicateGroups.prefix(10) {
        print("  \(g.count)× \(bytes(g.sizeEach))  keep: \(g.keeper.lastPathComponent)")
    }
    exit(0)
}

// `--scan-junk` verifies the Cleanup scanner (read-only).
if args.contains("--scan-junk") {
    let report = CleanupScanner().scan()
    print("Cleanup scan — \(report.items.count) items, \(bytes(report.totalBytes)) total (\(bytes(report.autoSelectedBytes)) auto-selected):\n")
    let grouped = Dictionary(grouping: report.items, by: \.category)
    for category in JunkCategory.allCases {
        guard let items = grouped[category] else { continue }
        let subtotal = items.reduce(0) { $0 + $1.sizeBytes }
        print("  [\(category.rawValue)] \(items.count) items — \(bytes(subtotal))\(category.autoSelect ? "" : "  (not auto-selected)")")
    }
    exit(0)
}

func appIndex(_ flag: String) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

if let target = appIndex("--app") {
    guard let app = scanner.resolve(nameOrPath: target) else {
        FileHandle.standardError.write(Data("No app found matching '\(target)'.\n".utf8))
        exit(1)
    }
    print("App:       \(app.name)")
    print("Bundle ID: \(app.bundleID)")
    print("Path:      \(app.url.path)\n")

    let plan = LeftoversFetcher().fetchLeftovers(for: app)
    if plan.items.isEmpty {
        print("No leftovers found.")
        exit(0)
    }

    print("Deep-clean would remove \(plan.items.count) items — \(bytes(plan.totalBytes)):\n")
    let grouped = Dictionary(grouping: plan.items, by: \.category)
    for category in LeftoverCategory.allCases {
        guard let items = grouped[category] else { continue }
        let subtotal = items.reduce(0) { $0 + $1.sizeBytes }
        print("  [\(category.rawValue)] — \(bytes(subtotal))")
        for item in items.sorted(by: { $0.sizeBytes > $1.sizeBytes }) {
            print("      \(bytes(item.sizeBytes).padding(toLength: 10, withPad: " ", startingAt: 0))  \(item.url.path)")
        }
    }

    if args.contains("--trash") {
        print("\nMoving to Trash…")
        let outcome = FileRemover().moveToTrash(plan)
        print("  Trashed:          \(outcome.trashed.count)")
        for f in outcome.failed { print("  FAILED \(f.url.path): \(f.error)") }

        if !outcome.needsPrivilege.isEmpty {
            print("  System-owned:     \(outcome.needsPrivilege.count)")
            let remover = PrivilegedFileRemover()
            if args.contains("--use-helper"), remover.isHelperReachable() {
                print("  Routing to root helper…")
                do {
                    let r = try remover.remove(paths: outcome.needsPrivilege.map(\.path))
                    print("    removed by helper: \(r.removed.count)")
                    for (p, e) in r.errors { print("    FAILED \(p): \(e)") }
                } catch {
                    print("    helper error: \(error)")
                }
            } else {
                for u in outcome.needsPrivilege { print("      (needs root helper) \(u.path)") }
                if args.contains("--use-helper") {
                    print("    helper not reachable — install it first (see Scripts/install-helper.sh)")
                }
            }
        }
    } else {
        print("\n(dry run — pass --trash to move these to the Trash)")
    }
} else {
    let apps = scanner.scan()
    print("\(apps.count) installed apps:\n")
    for app in apps {
        print("  \(app.name.padding(toLength: 34, withPad: " ", startingAt: 0)) \(app.bundleID)")
    }
    print("\nRun with --app \"<name>\" to deep-clean scan one.")
}
