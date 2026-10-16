import Foundation

/// Shared on-disk size measurement, used by the uninstaller and the cleanup
/// scanner. Sums allocated sizes of regular files (recursing into directories).
public enum FileSizing {
    public static func size(of url: URL, fileManager: FileManager = .default) -> UInt64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        if let vals = try? url.resourceValues(forKeys: keys), vals.isRegularFile == true {
            return UInt64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? 0)
        }
        var total: UInt64 = 0
        if let en = fileManager.enumerator(at: url, includingPropertiesForKeys: Array(keys),
                                           options: [], errorHandler: { _, _ in true }) {
            for case let f as URL in en {
                if let v = try? f.resourceValues(forKeys: keys), v.isRegularFile == true {
                    total += UInt64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
                }
            }
        }
        return total
    }
}
