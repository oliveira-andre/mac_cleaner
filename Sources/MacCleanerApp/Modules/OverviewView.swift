import SwiftUI
import MacCleanerCore
import MacCleanerUI

struct OverviewView: View {
    @ObservedObject var monitor: SystemMonitor

    private let mem: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .memory; return f }()
    private let file: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .file; return f }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                PageHeader(Module.overview)

                if let s = monitor.snapshot {
                    let cols = [GridItem(.adaptive(minimum: 240), spacing: Spacing.lg)]
                    LazyVGrid(columns: cols, spacing: Spacing.lg) {
                        memoryTile(s.memory)
                        cpuTile(s.cpu)
                        storageTile(s.storage)
                        wifiTile(s.network)
                        batteryTile(s.battery)
                        temperatureTile(s.temperature)
                    }
                    devicesSection(s.devices)
                } else {
                    LoadingState("Reading sensors…").frame(height: 240)
                }
            }
            .padding(Spacing.xxl)
        }
    }

    // MARK: Tiles

    private func memoryTile(_ m: MemoryMetrics) -> some View {
        tile("Memory", "\(Int(m.usedFraction * 100))%",
             "\(mem.string(fromByteCount: Int64(m.usedBytes))) of \(mem.string(fromByteCount: Int64(m.totalBytes)))",
             icon: "memorychip", fraction: m.usedFraction)
    }

    private func cpuTile(_ c: CPUMetrics) -> some View {
        tile("CPU", "\(Int(c.busyFraction * 100))%", "user + system", icon: "cpu", fraction: c.busyFraction)
    }

    private func storageTile(_ s: StorageMetrics) -> some View {
        tile("Storage", "\(Int(s.usedFraction * 100))%",
             "\(file.string(fromByteCount: Int64(s.usedBytes))) of \(file.string(fromByteCount: Int64(s.totalBytes)))",
             icon: "internaldrive", fraction: s.usedFraction)
    }

    private func wifiTile(_ n: NetworkMetrics) -> some View {
        let title = n.ssid ?? (n.isConnected ? "Connected" : "Not connected")
        return tile("Wi-Fi", title,
                    "↓ \(rate(n.downBytesPerSec))   ↑ \(rate(n.upBytesPerSec))",
                    icon: n.isConnected ? "wifi" : "wifi.slash", fraction: nil,
                    chipFill: n.isConnected ? Palette.accentVioletDeep : Palette.onDarkFaint)
    }

    private func batteryTile(_ b: BatteryMetrics) -> some View {
        tile("Battery", b.percent.map { "\($0)%" } ?? (b.hasBattery ? "—" : "N/A"),
             b.state.rawValue, icon: batteryIcon(b), fraction: b.percent.map { Double($0) / 100 },
             barColor: batteryBarColor(b))
    }

    /// Lime when charging/charged/plugged in; violet while discharging above
    /// the 20% critical threshold; hot pink at or below it.
    private func batteryBarColor(_ b: BatteryMetrics) -> Color {
        switch b.state {
        case .charging, .charged, .pluggedIn: return Palette.accentLime
        case .onBattery:                      return (b.percent ?? 100) <= 20 ? Palette.accentPink : Palette.accentViolet
        case .unknown:                        return Palette.accentViolet
        }
    }

    private func temperatureTile(_ t: TemperatureMetrics) -> some View {
        tile("CPU Temp", t.cpuCelsius.map { String(format: "%.1f°C", $0) } ?? "—",
             "thermal: \(t.thermalState.label)", icon: "thermometer.medium", fraction: nil)
    }

    // MARK: Devices

    @ViewBuilder private func devicesSection(_ devices: [ConnectedDevice]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionTitle("Connected Devices")
            if devices.isEmpty {
                Text("No external devices connected.").textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
            } else {
                DataTable {
                    ForEach(devices) { d in
                        HStack(spacing: Spacing.md) {
                            Image(systemName: d.kind == "Bluetooth" ? "dot.radiowaves.right" : "externaldrive")
                                .foregroundStyle(Palette.onDarkMuted).frame(width: 20)
                            Text(d.name).lineLimit(1)
                            Spacer(minLength: Spacing.md)
                            if let detail = d.detail {
                                Text(detail).textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
                            }
                            Badge(d.kind, kind: .token)
                        }
                        .dataTableRow()
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func tile(_ title: String, _ value: String, _ detail: String, icon: String,
                      fraction: Double?, barColor: Color? = nil,
                      chipFill: Color = Palette.accentVioletDeep) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                IconChip(icon, size: 28, fill: chipFill)
                Text(title).textStyle(.eyebrow).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
            }
            Text(value).textStyle(.headingLg).foregroundStyle(Palette.onPrimary).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
            if let fraction { UsageBar(fraction, tint: barColor) }
            Spacer(minLength: 0)
            Text(detail).textStyle(.caption).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .card()
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
}
