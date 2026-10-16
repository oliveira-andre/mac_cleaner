import Foundation

/// Boot-volume storage usage.
public struct StorageMetrics: Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public var freeBytes: UInt64 { totalBytes > usedBytes ? totalBytes - usedBytes : 0 }
    public var usedFraction: Double { totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes) }

    public static func read() -> StorageMetrics {
        let url = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]
        guard let v = try? url.resourceValues(forKeys: keys),
              let total = v.volumeTotalCapacity else {
            return StorageMetrics(totalBytes: 0, usedBytes: 0)
        }
        let available = UInt64(v.volumeAvailableCapacityForImportantUsage ?? 0)
        let totalU = UInt64(total)
        return StorageMetrics(totalBytes: totalU, usedBytes: totalU > available ? totalU - available : 0)
    }
}
