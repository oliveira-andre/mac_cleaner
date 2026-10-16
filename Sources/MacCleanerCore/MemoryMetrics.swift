import Darwin
import Foundation

/// Physical-memory usage, read from the Mach VM statistics — the same public
/// source CleanMyMac's HealthMonitor uses (`host_statistics64`).
public struct MemoryMetrics: Sendable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64      // App Memory + Wired + Compressed (Activity-Monitor style)
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let freeBytes: UInt64

    public var usedFraction: Double {
        totalBytes == 0 ? 0 : Double(usedBytes) / Double(totalBytes)
    }

    public static func read() -> MemoryMetrics {
        let total = ProcessInfo.processInfo.physicalMemory

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else {
            return MemoryMetrics(totalBytes: total, usedBytes: 0, wiredBytes: 0,
                                 compressedBytes: 0, freeBytes: total)
        }

        let active = UInt64(stats.active_count) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let free = UInt64(stats.free_count) * page

        // Activity Monitor's "Memory Used" ≈ app (active) + wired + compressed.
        let used = active + wired + compressed

        return MemoryMetrics(
            totalBytes: total,
            usedBytes: used,
            wiredBytes: wired,
            compressedBytes: compressed,
            freeBytes: free
        )
    }
}
