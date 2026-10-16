import Foundation

/// Locates per-browser privacy artifacts (history, cookies, cache) plus the
/// system recent-items lists. File-level, mirroring PrivacyScanning's Safari /
/// Chrome / Firefox scan tasks.
public struct PrivacyScanner {
    private let fileManager: FileManager
    private let home: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.home = fileManager.homeDirectoryForCurrentUser
    }

    public func scan() -> PrivacyReport {
        var items: [PrivacyItem] = []

        func add(_ browser: String, _ category: String, _ relativeToHome: String) {
            let url = home.appendingPathComponent(relativeToHome)
            guard fileManager.fileExists(atPath: url.path) else { return }
            let size = FileSizing.size(of: url, fileManager: fileManager)
            guard size > 0 else { return }
            items.append(PrivacyItem(browser: browser, category: category, url: url, sizeBytes: size))
        }

        // Safari (modern Safari keeps much in its container).
        add("Safari", "History", "Library/Safari/History.db")
        add("Safari", "Downloads List", "Library/Safari/Downloads.plist")
        add("Safari", "Cache", "Library/Caches/com.apple.Safari")

        // Chromium-family: same layout under different roots.
        let chromium: [(String, String)] = [
            ("Chrome", "Library/Application Support/Google/Chrome"),
            ("Brave",  "Library/Application Support/BraveSoftware/Brave-Browser"),
            ("Edge",   "Library/Application Support/Microsoft Edge"),
        ]
        for (name, root) in chromium {
            add(name, "History",    "\(root)/Default/History")
            add(name, "Cookies",    "\(root)/Default/Network/Cookies")
            add(name, "Cache",      "\(root)/Default/Cache")
        }

        // Firefox: profiles live under Profiles/<random>.default*.
        let ffProfiles = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
        if let profs = try? fileManager.contentsOfDirectory(at: ffProfiles, includingPropertiesForKeys: nil) {
            for p in profs {
                let rel = "Library/Application Support/Firefox/Profiles/\(p.lastPathComponent)"
                add("Firefox", "History",  "\(rel)/places.sqlite")
                add("Firefox", "Cookies",  "\(rel)/cookies.sqlite")
            }
        }
        add("Firefox", "Cache", "Library/Caches/Firefox")

        // System recent items.
        add("System", "Recent Items", "Library/Application Support/com.apple.sharedfilelist")

        return PrivacyReport(items: items.sorted { $0.sizeBytes > $1.sizeBytes })
    }
}
