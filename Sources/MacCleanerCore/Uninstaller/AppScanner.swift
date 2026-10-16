import AppKit
import Foundation

/// Enumerates installed `.app` bundles and resolves their identifiers.
public struct AppScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Standard application locations (user + system domains).
    public func searchRoots() -> [(url: URL, isSystem: Bool)] {
        let home = fileManager.homeDirectoryForCurrentUser
        return [
            (URL(fileURLWithPath: "/Applications"), true),
            (URL(fileURLWithPath: "/Applications/Utilities"), true),
            (home.appendingPathComponent("Applications"), false),
        ]
    }

    public func scan() -> [InstalledApp] {
        var apps: [InstalledApp] = []
        for root in searchRoots() {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: root.url, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]) else { continue }
            for entry in entries where entry.pathExtension == "app" {
                if let app = resolve(url: entry, isSystem: root.isSystem) {
                    apps.append(app)
                }
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Resolve a single `.app` by name or path (as a user would target one).
    public func resolve(nameOrPath: String) -> InstalledApp? {
        if nameOrPath.hasSuffix(".app") || nameOrPath.contains("/") {
            let url = URL(fileURLWithPath: (nameOrPath as NSString).expandingTildeInPath)
            return resolve(url: url, isSystem: !url.path.hasPrefix(fileManager.homeDirectoryForCurrentUser.path))
        }
        let target = nameOrPath.lowercased()
        return scan().first {
            $0.name.lowercased() == target || $0.url.deletingPathExtension().lastPathComponent.lowercased() == target
        }
    }

    public func resolve(url: URL, isSystem: Bool) -> InstalledApp? {
        guard fileManager.fileExists(atPath: url.path),
              let bundle = Bundle(url: url) else { return nil }
        let info = bundle.infoDictionary ?? [:]
        let bundleID = bundle.bundleIdentifier ?? ""
        let name = (info["CFBundleName"] as? String)
            ?? (info["CFBundleDisplayName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        guard !bundleID.isEmpty else { return nil }
        return InstalledApp(url: url, name: name, bundleID: bundleID, isSystem: isSystem)
    }
}
