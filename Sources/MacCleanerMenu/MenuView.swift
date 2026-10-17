import MacCleanerCore
import MacCleanerUI
import SwiftUI

struct MenuView: View {
    @ObservedObject var monitor: SystemMonitor

    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Text("Mac").textStyle(.headingSm).foregroundStyle(Palette.onPrimary)
                KeywordChip("Health", style: .headingSm)
            }
            .padding(.bottom, Spacing.xs)

            if let snap = monitor.snapshot {
                memorySection(snap.memory)
                cpuSection(snap.cpu)
                temperatureSection(snap.temperature)
            } else {
                Text("Reading sensors…").textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.action(.ghost, size: .small))
            }
        }
        .padding(Spacing.lg)
        .frame(width: 300, height: 360, alignment: .topLeading)
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

    private func cpuSection(_ c: CPUMetrics) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            label("CPU", detail: String(format: "%.0f%%", c.busyFraction * 100))
            UsageBar(c.busyFraction)
        }
        .card(padding: Spacing.md)
    }

    // MARK: - Temperature

    private func temperatureSection(_ t: TemperatureMetrics) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            label("Temperature", detail: t.thermalState.label)
            HStack(spacing: Spacing.xl) {
                tempReadout("CPU", t.cpuCelsius)
                tempReadout("Battery", t.batteryCelsius)
            }
        }
        .card(padding: Spacing.md)
    }

    private func tempReadout(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title).textStyle(.microCap).foregroundStyle(Palette.onDarkMuted)
            Text(value.map { String(format: "%.1f°C", $0) } ?? "—")
                .textStyle(.headingSm).foregroundStyle(Palette.onPrimary).monospacedDigit()
        }
    }

    // MARK: - Helpers

    private func label(_ title: String, detail: String) -> some View {
        HStack {
            Text(title).textStyle(.microCap).foregroundStyle(Palette.onDarkMuted)
            Spacer()
            Text(detail).textStyle(.caption).foregroundStyle(Palette.onPrimary).monospacedDigit()
        }
    }
}
