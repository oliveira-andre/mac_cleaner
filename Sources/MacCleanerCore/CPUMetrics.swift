import Darwin
import Foundation

/// System-wide CPU load, derived from the delta of cumulative tick counters
/// (`host_statistics` / HOST_CPU_LOAD_INFO) between two samples.
public struct CPUMetrics: Sendable {
    public let userFraction: Double
    public let systemFraction: Double
    public let idleFraction: Double

    public var busyFraction: Double { userFraction + systemFraction }
}

/// Stateful sampler — keeps the previous tick snapshot so it can compute a
/// delta. Not thread-safe; drive it from one place (e.g. the monitor timer).
public final class CPUSampler {
    private var previous: host_cpu_load_info?

    public init() {}

    public func sample() -> CPUMetrics {
        guard let load = Self.readLoad() else {
            return CPUMetrics(userFraction: 0, systemFraction: 0, idleFraction: 1)
        }
        defer { previous = load }

        guard let prev = previous else {
            return CPUMetrics(userFraction: 0, systemFraction: 0, idleFraction: 1)
        }

        let user = Double(load.cpu_ticks.0 &- prev.cpu_ticks.0)
        let sys = Double(load.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = user + sys + idle + nice
        guard total > 0 else {
            return CPUMetrics(userFraction: 0, systemFraction: 0, idleFraction: 1)
        }

        return CPUMetrics(
            userFraction: (user + nice) / total,
            systemFraction: sys / total,
            idleFraction: idle / total
        )
    }

    private static func readLoad() -> host_cpu_load_info? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? info : nil
    }
}
