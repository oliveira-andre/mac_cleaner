import SwiftUI
import MacCleanerCore

struct OverviewView: View {
    @ObservedObject var monitor: SystemMonitor

    private let mem: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .memory; return f }()
    private let file: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .file; return f }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("System Health").font(.largeTitle.weight(.bold))

                if let s = monitor.snapshot {
                    let cols = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: cols, spacing: 16) {
                        memoryTile(s.memory)
                        cpuTile(s.cpu)
                        storageTile(s.storage)
                        wifiTile(s.network)
                        batteryTile(s.battery)
                        temperatureTile(s.temperature)
                    }
                    devicesSection(s.devices)
                } else {
                    ProgressView("Reading sensors…")
                }
                Spacer()
            }
            .padding(28)
        }
    }

    // MARK: Tiles

    private func memoryTile(_ m: MemoryMetrics) -> some View {
        tile("Memory", "\(Int(m.usedFraction * 100))%",
             "\(mem.string(fromByteCount: Int64(m.usedBytes))) of \(mem.string(fromByteCount: Int64(m.totalBytes)))",
             fraction: m.usedFraction)
    }

    private func cpuTile(_ c: CPUMetrics) -> some View {
        tile("CPU", "\(Int(c.busyFraction * 100))%", "user + system", fraction: c.busyFraction)
    }

    private func storageTile(_ s: StorageMetrics) -> some View {
        tile("Storage", "\(Int(s.usedFraction * 100))%",
             "\(file.string(fromByteCount: Int64(s.usedBytes))) of \(file.string(fromByteCount: Int64(s.totalBytes)))",
             fraction: s.usedFraction)
    }

    private func wifiTile(_ n: NetworkMetrics) -> some View {
        let title = n.ssid ?? (n.isConnected ? "Connected" : "Not connected")
        return tile("Wi-Fi", title,
                    "↓ \(rate(n.downBytesPerSec))   ↑ \(rate(n.upBytesPerSec))",
                    fraction: nil, icon: n.isConnected ? "wifi" : "wifi.slash",
                    tint: n.isConnected ? .blue : .secondary)
    }

    private func batteryTile(_ b: BatteryMetrics) -> some View {
        tile("Battery", b.percent.map { "\($0)%" } ?? (b.hasBattery ? "—" : "N/A"),
             b.state.rawValue, fraction: b.percent.map { Double($0) / 100 },
             icon: batteryIcon(b), tint: b.state == .onBattery ? .orange : .green,
             barColor: batteryBarColor(b))
    }

    /// Green when charging/charged/plugged in; white while discharging above the
    /// 20% critical threshold; red at or below it.
    private func batteryBarColor(_ b: BatteryMetrics) -> Color {
        switch b.state {
        case .charging, .charged, .pluggedIn: return .green
        case .onBattery:                      return (b.percent ?? 100) <= 20 ? .red : .white
        case .unknown:                        return .white
        }
    }

    private func temperatureTile(_ t: TemperatureMetrics) -> some View {
        tile("CPU Temp", t.cpuCelsius.map { String(format: "%.1f°C", $0) } ?? "—",
             "thermal: \(t.thermalState.label)", fraction: nil, icon: "thermometer.medium", tint: .red)
    }

    // MARK: Devices

    @ViewBuilder private func devicesSection(_ devices: [ConnectedDevice]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connected Devices").font(.headline)
            if devices.isEmpty {
                Text("No external devices connected.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(devices) { d in
                    HStack(spacing: 10) {
                        Image(systemName: d.kind == "Bluetooth" ? "dot.radiowaves.right" : "externaldrive")
                            .foregroundStyle(.secondary).frame(width: 22)
                        Text(d.name)
                        Spacer()
                        if let detail = d.detail {
                            Text(detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(d.kind).font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: Helpers

    private func tile(_ title: String, _ value: String, _ detail: String,
                      fraction: Double?, icon: String? = nil, tint: Color = .blue,
                      barColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).foregroundStyle(tint) }
                Text(title).font(.headline)
            }
            Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            if let fraction { ProgressView(value: min(max(fraction, 0), 1)).tint(barColor ?? color(for: fraction)) }
            Spacer(minLength: 4)
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }

    private func rate(_ bps: UInt64) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f MB/s", Double(bps) / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0f KB/s", Double(bps) / 1_000) }
        return "\(bps) B/s"
    }

    private func batteryIcon(_ b: BatteryMetrics) -> String {
        if !b.hasBattery { return "powerplug" }
        if b.state == .charging || b.state == .charged { return "battery.100.bolt" }
        guard let p = b.percent else { return "battery.50" }
        switch p { case ..<15: return "battery.0"; case ..<40: return "battery.25"
        case ..<70: return "battery.50"; case ..<90: return "battery.75"; default: return "battery.100" }
    }

    private func color(for f: Double) -> Color {
        switch f { case ..<0.6: return .green; case ..<0.85: return .yellow; default: return .red }
    }
}
