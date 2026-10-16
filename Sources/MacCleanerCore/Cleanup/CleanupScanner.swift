import Foundation

/// Finds removable junk across the standard user-domain locations, listing each
/// category's immediate children so the user can deselect individual entries
/// (as CleanMyMac does). Sizes every item.
public struct CleanupScanner {
    private let fileManager: FileManager
    private let home: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.home = fileManager.homeDirectoryForCurrentUser
    }

    /// (root directory, category) pairs; items are the root's direct children.
    private func roots() -> [(URL, JunkCategory)] {
        let lib = home.appendingPathComponent("Library")
        let dev = lib.appendingPathComponent("Developer/Xcode")
        return [
            (lib.appendingPathComponent("Caches"), .userCaches),
            (lib.appendingPathComponent("Logs"), .userLogs),
            (lib.appendingPathComponent("Saved Application State"), .savedState),
            (home.appendingPathComponent(".Trash"), .trash),
            (dev.appendingPathComponent("DerivedData"), .xcodeDerivedData),
            (dev.appendingPathComponent("Archives"), .xcodeArchives),
            (dev.appendingPathComponent("iOS DeviceSupport"), .xcodeDeviceSupport),
        ]
    }

    public func scan() -> CleanupReport {
        var items: [JunkItem] = []
        for (root, category) in roots() {
            guard let children = try? fileManager.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: []) else { continue }
            for child in children {
                let size = FileSizing.size(of: child, fileManager: fileManager)
                guard size > 0 else { continue }
                items.append(JunkItem(url: child, category: category, sizeBytes: size))
            }
        }
        return CleanupReport(items: items.sorted { $0.sizeBytes > $1.sizeBytes })
    }
}
