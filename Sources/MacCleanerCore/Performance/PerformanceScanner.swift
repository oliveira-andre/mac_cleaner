import Foundation

/// Enumerates launch agents/daemons and reads their plists — CleanMyMac's
/// `LaunchAgentScanLocationsProvider` + `LaunchAgentModelFactory`.
public struct PerformanceScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    private func locations() -> [(URL, StartupItem.Kind, StartupItem.Domain)] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            (home.appendingPathComponent("Library/LaunchAgents"), .launchAgent, .user),
            (URL(fileURLWithPath: "/Library/LaunchAgents"), .launchAgent, .system),
            (URL(fileURLWithPath: "/Library/LaunchDaemons"), .launchDaemon, .system),
        ]
    }

    public func scanStartupItems() -> [StartupItem] {
        var items: [StartupItem] = []
        for (dir, kind, domain) in locations() {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for plist in entries where plist.pathExtension == "plist" {
                guard let data = try? Data(contentsOf: plist),
                      let obj = try? PropertyListSerialization.propertyList(from: data, format: nil),
                      let dict = obj as? [String: Any] else { continue }

                let label = (dict["Label"] as? String) ?? plist.deletingPathExtension().lastPathComponent
                var program = dict["Program"] as? String
                if program == nil, let args = dict["ProgramArguments"] as? [String] { program = args.first }
                let runAtLoad = (dict["RunAtLoad"] as? Bool) ?? false
                let disabled = (dict["Disabled"] as? Bool) ?? false

                items.append(StartupItem(
                    label: label, programPath: program, plistURL: plist,
                    kind: kind, domain: domain, runAtLoad: runAtLoad, enabled: !disabled))
            }
        }
        return items.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    public func scan() -> PerformanceReport {
        PerformanceReport(startupItems: scanStartupItems(), memory: MemoryMetrics.read())
    }
}

/// Runs maintenance tasks. User-level tasks execute directly; root tasks are
/// refused here (they belong on the privileged helper).
public struct MaintenanceRunner {
    public enum RunError: Error, CustomStringConvertible {
        case needsRoot, failed(Int32, String)
        public var description: String {
            switch self {
            case .needsRoot: return "this task needs the privileged helper"
            case .failed(let code, let out): return "exit \(code): \(out)"
            }
        }
    }

    public init() {}

    @discardableResult
    public func run(_ task: MaintenanceTask) throws -> String {
        guard !task.requiresRoot else { throw RunError.needsRoot }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: task.command[0])
        proc.arguments = Array(task.command.dropFirst())
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard proc.terminationStatus == 0 else { throw RunError.failed(proc.terminationStatus, out) }
        return out
    }
}
