import MacCleanerCore
import MacCleanerUI
import SwiftUI

struct MenuView: View {
    @ObservedObject var monitor: SystemMonitor
    let openApp: () -> Void

    /// Rows shown before the devices list collapses into "+N more".
    private let maxDevices = 4

    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        return f
    }()

    /// Decimal units for disk sizes, matching Finder and the Overview tile.
    private let fileFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let snap = monitor.snapshot {
                memorySection(snap.memory)
                cpuSection(snap.cpu, snap.temperature)
                storageSection(snap.storage)
                batterySection(snap.battery)
                networkSection(snap.network)
                devicesSection(snap.devices)
            } else {
                Text("Reading sensors…").textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
            }

            footer
        }
        .padding(Spacing.lg)
        .frame(width: 300, alignment: .topLeading)
        .background(Palette.canvas)
        .preferredColorScheme(.dark)
        .hidesFocusRing()
    }

    // MARK: - RAM

    private func memorySection(_ m: MemoryMetrics) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            label("Memory", detail: "\(byteFormatter.string(fromByteCount: Int64(m.usedBytes))) of \(byteFormatter.string(fromByteCount: Int64(m.totalBytes)))")
            UsageBar(m.usedFraction)
            Text("Wired \(byteFormatter.string(fromByteCount: Int64(m.wiredBytes))) · Compressed \(byteFormatter.string(fromByteCount: Int64(m.compressedBytes)))")
                .textStyle(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(Palette.onDarkMuted)
        }
        .card(padding: Spacing.md)
    }

    // MARK: - CPU

    private func cpuSection(_ c: CPUMetrics, _ t: TemperatureMetrics) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            label("CPU", detail: String(format: "%.0f%%", c.busyFraction * 100))
            UsageBar(c.busyFraction)
            HStack(spacing: Spacing.xl) {
                readout("Temperature", t.cpuCelsius.map { String(format: "%.1f°C", $0) } ?? "—")
                readout("Thermal", t.thermalState.label,
                        tint: t.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
                            ? Palette.accentPink : Palette.onPrimary)
            }
        }
        .card(padding: Spacing.md)
    }

    // MARK: - Storage

    private func storageSection(_ s: StorageMetrics) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            label("Storage", detail: "\(fileFormatter.string(fromByteCount: Int64(s.usedBytes))) of \(fileFormatter.string(fromByteCount: Int64(s.totalBytes)))")
            UsageBar(s.usedFraction)
            Text("\(fileFormatter.string(fromByteCount: Int64(s.freeBytes))) free")
                .textStyle(.caption)
                .foregroundStyle(Palette.onDarkMuted)
        }
        .card(padding: Spacing.md)
    }

    // MARK: - Battery

    private func batterySection(_ b: BatteryMetrics) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            label("Battery", detail: b.percent.map { "\($0)%" } ?? "—")
            if let p = b.percent { UsageBar(Double(p) / 100, tint: batteryBarColor(b)) }
            HStack(spacing: Spacing.sm) {
                Image(systemName: batteryIcon(b)).foregroundStyle(batteryBarColor(b))
                Text(b.state.rawValue).textStyle(.caption).foregroundStyle(Palette.onPrimary)
            }
        }
        .card(padding: Spacing.md)
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

    private func batteryIcon(_ b: BatteryMetrics) -> String {
        if !b.hasBattery { return "powerplug" }
        if b.state == .charging || b.state == .charged { return "battery.100.bolt" }
        guard let p = b.percent else { return "battery.50" }
        switch p { case ..<15: return "battery.0"; case ..<40: return "battery.25"
        case ..<70: return "battery.50"; case ..<90: return "battery.75"; default: return "battery.100" }
    }

    // MARK: - Internet

    private func networkSection(_ n: NetworkMetrics) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            label("Internet", detail: n.isOnline ? "Connected" : "Offline",
                  tint: n.isOnline ? Palette.accentLime : Palette.accentPink)
            if let link = n.link {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: link == .wifi ? "wifi" : "network").foregroundStyle(Palette.onDarkMuted)
                    Text(link == .wifi ? n.ssid ?? link.rawValue : link.rawValue)
                        .textStyle(.caption).foregroundStyle(Palette.onPrimary).lineLimit(1)
                }
            }
            HStack(spacing: Spacing.xl) {
                readout("↓ Receiving", rate(n.downBytesPerSec))
                readout("↑ Sending", rate(n.upBytesPerSec))
            }
        }
        .card(padding: Spacing.md)
    }

    private func rate(_ bps: UInt64) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f MB/s", Double(bps) / 1_000_000) }
        if bps >= 1_000 { return String(format: "%.0f KB/s", Double(bps) / 1_000) }
        return "\(bps) B/s"
    }

    // MARK: - Devices

    private func devicesSection(_ devices: [ConnectedDevice]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            label("Devices", detail: devices.isEmpty ? "None" : "\(devices.count) connected")
            ForEach(devices.prefix(maxDevices)) { d in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: d.kind == "Bluetooth" ? "dot.radiowaves.right" : "externaldrive")
                        .foregroundStyle(Palette.onDarkMuted).frame(width: 16)
                    Text(d.name).foregroundStyle(Palette.onPrimary).lineLimit(1)
                    Spacer(minLength: Spacing.sm)
                    if let detail = d.detail { Text(detail).foregroundStyle(Palette.onDarkMuted) }
                }
                .textStyle(.caption)
            }
            if devices.count > maxDevices {
                Text("+\(devices.count - maxDevices) more").textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
            }
        }
        .card(padding: Spacing.md)
    }

    // MARK: - Footer

    /// Open the app (left, the status-item glyph), the app name, Quit (right).
    private var footer: some View {
        HStack {
            iconButton("gauge.with.dots.needle.33percent", help: "Open MacCleaner",
                       fill: Palette.accentVioletDeep, action: openApp)
            Spacer()
            Text("MacCleaner").textStyle(.bodyStrong).foregroundStyle(Palette.onPrimary)
            Spacer()
            iconButton("rectangle.portrait.and.arrow.right", help: "Quit",
                       fill: Palette.onDarkFaint) { NSApplication.shared.terminate(nil) }
        }
        .padding(.top, Spacing.xs)
    }

    private func iconButton(_ symbol: String, help: String, fill: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) { IconChip(symbol, size: 28, fill: fill) }
            .buttonStyle(.plain)
            .help(help)
            .accessibilityLabel(help)
    }

    // MARK: - Helpers

    private func label(_ title: String, detail: String, tint: Color = Palette.onPrimary) -> some View {
        HStack {
            Text(title).textStyle(.microCap).foregroundStyle(Palette.onDarkMuted)
            Spacer()
            Text(detail).textStyle(.caption).foregroundStyle(tint).monospacedDigit()
        }
    }

    private func readout(_ title: String, _ value: String, tint: Color = Palette.onPrimary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).textStyle(.microCap).foregroundStyle(Palette.onDarkMuted)
            Text(value).textStyle(.bodyStrong).foregroundStyle(tint).monospacedDigit().lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
