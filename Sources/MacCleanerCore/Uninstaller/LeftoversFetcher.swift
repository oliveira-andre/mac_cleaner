import Foundation

/// Finds every file belonging to an app — the "deep clean" step.
///
/// Reconstructed from CleanMyMac 5's `UninstallerScanning` (`LeftoversFetcher`):
/// it keys off the app's **name** and **bundle id**, expands a fixed set of
/// `~/Library` and `/Library` locations, and verifies sandbox containers by
/// reading each container's metadata plist rather than trusting the folder name.
public struct LeftoversFetcher {
    private let fileManager: FileManager
    private let userLibrary: URL
    private let systemLibrary = URL(fileURLWithPath: "/Library")

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.userLibrary = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
    }

    public func fetchLeftovers(for app: InstalledApp, includeAppBundle: Bool = true) -> UninstallPlan {
        var found: [LeftoverItem] = []
        var seen = Set<String>()

        func add(_ url: URL, _ category: LeftoverCategory) {
            let path = url.path
            guard !seen.contains(path), fileManager.fileExists(atPath: path) else { return }
            seen.insert(path)
            found.append(LeftoverItem(url: url, category: category, sizeBytes: size(of: url)))
        }

        let b = app.bundleID
        let n = app.name

        if includeAppBundle { add(app.url, .binary) }

        for lib in [userLibrary, systemLibrary] {
            // Application Support — by name and by bundle id
            add(lib.appendingPathComponent("Application Support/\(n)"), .applicationSupport)
            add(lib.appendingPathComponent("Application Support/\(b)"), .applicationSupport)
            add(lib.appendingPathComponent("Application Support/CrashReporter/\(n)"), .crashReports)

            add(lib.appendingPathComponent("Caches/\(b)"), .caches)
            add(lib.appendingPathComponent("Caches/\(n)"), .caches)

            add(lib.appendingPathComponent("Preferences/\(b).plist"), .preferences)
            add(lib.appendingPathComponent("Preferences/\(n).plist"), .preferences)

            add(lib.appendingPathComponent("Logs/\(n)"), .logs)
            add(lib.appendingPathComponent("Logs/\(b)"), .logs)

            add(lib.appendingPathComponent("HTTPStorages/\(b)"), .httpStorages)
            add(lib.appendingPathComponent("WebKit/\(b)"), .webKit)
        }

        // User-domain only
        add(userLibrary.appendingPathComponent("Saved Application State/\(b).savedState"), .savedState)
        add(userLibrary.appendingPathComponent("Cookies/\(b).binarycookies"), .cookies)
        add(userLibrary.appendingPathComponent("Application Scripts/\(b)"), .applicationScripts)
        add(userLibrary.appendingPathComponent("Containers/\(b)"), .containers)

        // Sandbox + group containers: match by metadata identifier, not folder name.
        for dir in metadataMatchedContainers(bundleID: b) {
            add(dir.url, dir.category)
        }

        // Launch agents/daemons whose plist Label matches the bundle id.
        for lib in [userLibrary, systemLibrary] {
            for sub in ["LaunchAgents", "LaunchDaemons"] {
                for plist in launchPlists(in: lib.appendingPathComponent(sub), matching: b) {
                    add(plist, .launchAgents)
                }
            }
        }

        return UninstallPlan(app: app, items: found)
    }

    // MARK: - Container metadata verification

    private func metadataMatchedContainers(bundleID: String) -> [(url: URL, category: LeftoverCategory)] {
        var result: [(URL, LeftoverCategory)] = []
        let targets: [(URL, LeftoverCategory)] = [
            (userLibrary.appendingPathComponent("Containers"), .containers),
            (userLibrary.appendingPathComponent("Group Containers"), .groupContainers),
        ]
        for (root, category) in targets {
            guard let entries = try? fileManager.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for entry in entries {
                if containerIdentifier(at: entry) == bundleID
                    || entry.lastPathComponent.contains(bundleID) {
                    result.append((entry, category))
                }
            }
        }
        return result
    }

    private func containerIdentifier(at container: URL) -> String? {
        let meta = container.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
        guard let data = try? Data(contentsOf: meta),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any] else { return nil }
        return dict["MCMMetadataIdentifier"] as? String
    }

    // MARK: - Launch plist matching

    private func launchPlists(in dir: URL, matching bundleID: String) -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        return entries.filter { plist in
            guard plist.pathExtension == "plist" else { return false }
            if plist.deletingPathExtension().lastPathComponent.hasPrefix(bundleID) { return true }
            guard let data = try? Data(contentsOf: plist),
                  let obj = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let dict = obj as? [String: Any] else { return false }
            if let label = dict["Label"] as? String, label.hasPrefix(bundleID) { return true }
            if let prog = dict["Program"] as? String, prog.contains(bundleID) { return true }
            if let args = dict["ProgramArguments"] as? [String],
               args.contains(where: { $0.contains(bundleID) }) { return true }
            return false
        }
    }

    // MARK: - Sizing

    func size(of url: URL) -> UInt64 {
        FileSizing.size(of: url, fileManager: fileManager)
    }
}
