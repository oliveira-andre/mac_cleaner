import Darwin
import Foundation
import Network
#if canImport(CoreWLAN)
import CoreWLAN
#endif

/// Internet reachability, Wi-Fi association + live throughput.
public struct NetworkMetrics: Sendable {
    public enum Link: String, Sendable {
        case wifi     = "Wi-Fi"
        case ethernet = "Ethernet"
        case other    = "Network"
    }

    public let link: Link?              // interface the default route uses; nil when offline
    public let ssid: String?            // nil if off, not Wi-Fi, or name blocked (needs Location)
    public let isConnected: Bool        // Wi-Fi associated (says nothing about Ethernet)
    public let downBytesPerSec: UInt64
    public let upBytesPerSec: UInt64

    public var isOnline: Bool { link != nil }
}

/// Stateful: throughput is the delta of interface byte counters between samples.
public final class NetworkSampler {
    private var prevIn: UInt64 = 0
    private var prevOut: UInt64 = 0
    private var prevTime: Date?
    // Reachability over any interface. `currentPath` is unsatisfied until the
    // first update lands, so the very first sample can read offline.
    private let pathMonitor = NWPathMonitor()

    public init() {
        pathMonitor.start(queue: DispatchQueue(label: "io.partnerfleet.maccleaner.network-path"))
    }

    deinit { pathMonitor.cancel() }

    public func sample() -> NetworkMetrics {
        let (bin, bout) = Self.interfaceBytes()
        let now = Date()
        var down: UInt64 = 0, up: UInt64 = 0
        if let t = prevTime {
            let dt = now.timeIntervalSince(t)
            if dt > 0 {
                if bin >= prevIn { down = UInt64(Double(bin - prevIn) / dt) }
                if bout >= prevOut { up = UInt64(Double(bout - prevOut) / dt) }
            }
        }
        prevIn = bin; prevOut = bout; prevTime = now
        let (ssid, connected) = Self.wifiStatus()
        return NetworkMetrics(link: Self.link(of: pathMonitor.currentPath), ssid: ssid, isConnected: connected,
                              downBytesPerSec: down, upBytesPerSec: up)
    }

    static func link(of path: NWPath) -> NetworkMetrics.Link? {
        guard path.status == .satisfied else { return nil }
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        return .other
    }

    /// Sum rx/tx bytes over physical interfaces (excludes loopback).
    static func interfaceBytes() -> (UInt64, UInt64) {
        var inB: UInt64 = 0, outB: UInt64 = 0
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let p = ptr {
            let ifa = p.pointee
            if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ifa.ifa_name)
                if name != "lo0", let data = ifa.ifa_data {
                    let d = data.assumingMemoryBound(to: if_data.self).pointee
                    inB += UInt64(d.ifi_ibytes)
                    outB += UInt64(d.ifi_obytes)
                }
            }
            ptr = ifa.ifa_next
        }
        return (inB, outB)
    }

    static func wifiStatus() -> (String?, Bool) {
        #if canImport(CoreWLAN)
        guard let iface = CWWiFiClient.shared().interface() else { return (nil, false) }
        let connected = iface.powerOn() && iface.rssiValue() != 0
        return (iface.ssid(), connected)
        #else
        return (nil, false)
        #endif
    }
}
