import CryptoKit
import Foundation

/// Scans the user's document folders for large/old files and exact duplicates.
/// One directory walk feeds both analyses. Mirrors OrganizeModule's scope
/// (home-folder document locations; needs Full Disk Access for the full set).
public struct OrganizeScanner {
    public struct Thresholds: Sendable {
        public var largeFileMin: UInt64        // always "large" at/above this
        public var staleFileMin: UInt64        // "old" candidate at/above this …
        public var staleDays: Int              // … if unused for this many days
        public var duplicateMin: UInt64        // ignore dup candidates below this
        public init(largeFileMin: UInt64 = 100 * 1_048_576,
                    staleFileMin: UInt64 = 10 * 1_048_576,
                    staleDays: Int = 365,
                    duplicateMin: UInt64 = 1_048_576) {
            self.largeFileMin = largeFileMin
            self.staleFileMin = staleFileMin
            self.staleDays = staleDays
            self.duplicateMin = duplicateMin
        }
    }

    private let fileManager: FileManager
    private let roots: [URL]
    private let thresholds: Thresholds

    public init(roots: [URL]? = nil, thresholds: Thresholds = Thresholds(),
                fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.thresholds = thresholds
        let home = fileManager.homeDirectoryForCurrentUser
        self.roots = roots ?? ["Downloads", "Documents", "Desktop", "Movies"]
            .map { home.appendingPathComponent($0) }
    }

    private struct FileInfo { let url: URL; let size: UInt64; let lastUsed: Date }

    private func enumerateFiles() -> [FileInfo] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey, .contentAccessDateKey, .contentModificationDateKey,
        ]
        var infos: [FileInfo] = []
        for root in roots {
            guard let en = fileManager.enumerator(
                at: root, includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }) else { continue }
            for case let url as URL in en {
                guard let v = try? url.resourceValues(forKeys: keys),
                      v.isRegularFile == true, v.isSymbolicLink != true else { continue }
                let size = UInt64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
                guard size > 0 else { continue }
                let lastUsed = [v.contentAccessDate, v.contentModificationDate]
                    .compactMap { $0 }.max() ?? .distantPast
                infos.append(FileInfo(url: url, size: size, lastUsed: lastUsed))
            }
        }
        return infos
    }

    public func scan() -> ClutterReport {
        let files = enumerateFiles()
        return ClutterReport(
            largeOldFiles: largeOld(from: files),
            duplicateGroups: duplicates(from: files)
        )
    }

    private func largeOld(from files: [FileInfo]) -> [LargeOldFile] {
        let staleCutoff = Calendar.current.date(byAdding: .day, value: -thresholds.staleDays, to: Date()) ?? .distantPast
        return files.compactMap { f -> LargeOldFile? in
            let isLarge = f.size >= thresholds.largeFileMin
            let isOld = f.size >= thresholds.staleFileMin && f.lastUsed < staleCutoff
            guard isLarge || isOld else { return nil }
            return LargeOldFile(url: f.url, sizeBytes: f.size, lastUsed: f.lastUsed)
        }.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private func duplicates(from files: [FileInfo]) -> [DuplicateGroup] {
        // Only files big enough to matter, and only sizes shared by >1 file
        // get hashed — keeps the expensive step bounded.
        let candidates = files.filter { $0.size >= thresholds.duplicateMin }
        let bySize = Dictionary(grouping: candidates, by: \.size).filter { $0.value.count > 1 }

        var byHash: [String: [URL]] = [:]
        var sizeForHash: [String: UInt64] = [:]
        for (size, group) in bySize {
            for f in group {
                guard let hash = Self.sha256(of: f.url) else { continue }
                byHash[hash, default: []].append(f.url)
                sizeForHash[hash] = size
            }
        }
        return byHash.compactMap { (hash, urls) -> DuplicateGroup? in
            guard urls.count > 1 else { return nil }
            return DuplicateGroup(contentHash: hash, urls: urls.sorted { $0.path < $1.path },
                                  sizeEach: sizeForHash[hash] ?? 0)
        }.sorted { $0.reclaimableBytes > $1.reclaimableBytes }
    }

    static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
