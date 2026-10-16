import Foundation

/// Removes leftovers. For the unprivileged MVP this moves items to the Trash
/// (reversible). In CleanMyMac, items the user can't write route instead to the
/// root Agent's `PrivilegedFileRemover` over XPC — that path will live in the
/// separate helper target.
public struct FileRemover {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public struct Outcome: Sendable {
        public let trashed: [URL]
        public let needsPrivilege: [URL]   // not writable by this user → helper territory
        public let failed: [(url: URL, error: String)]
    }

    public func moveToTrash(_ plan: UninstallPlan) -> Outcome {
        moveToTrash(urls: plan.items.map(\.url))
    }

    public func moveToTrash(urls: [URL]) -> Outcome {
        var trashed: [URL] = []
        var needsPrivilege: [URL] = []
        var failed: [(URL, String)] = []

        for url in urls {
            if !fileManager.isWritableFile(atPath: url.deletingLastPathComponent().path) {
                needsPrivilege.append(url)
                continue
            }
            do {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
                trashed.append(url)
            } catch {
                failed.append((url, error.localizedDescription))
            }
        }
        return Outcome(trashed: trashed, needsPrivilege: needsPrivilege, failed: failed)
    }
}
