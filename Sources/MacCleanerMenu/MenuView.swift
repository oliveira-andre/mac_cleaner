import MacCleanerCore
import SwiftUI

struct MenuView: View {
    @ObservedObject var monitor: SystemMonitor

    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .memory
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mac Health")
                .font(.headline)

            if let snap = monitor.snapshot {
                memorySection(snap.memory)
                cpuSection(snap.cpu)
                temperatureSection(snap.temperature)
            } else {
                Text("Reading sensors…").foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 300, height: 360, alignment: .topLeading)
    }

    // MARK: - RAM

    private func memorySection(_ m: MemoryMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Memory", detail: "\(byteFormatter.string(fromByteCount: Int64(m.usedBytes))) of \(byteFormatter.string(fromByteCount: Int64(m.totalBytes)))")
            ProgressView(value: m.usedFraction)
                .tint(color(for: m.usedFraction))
            Text("Wired \(byteFormatter.string(fromByteCount: Int64(m.wiredBytes)))  ·  Compressed \(byteFormatter.string(fromByteCount: Int64(m.compressedBytes)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - CPU

    private func cpuSection(_ c: CPUMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label("CPU", detail: String(format: "%.0f%%", c.busyFraction * 100))
            ProgressView(value: min(c.busyFraction, 1))
                .tint(color(for: c.busyFraction))
        }
    }

    // MARK: - Temperature

    private func temperatureSection(_ t: TemperatureMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Temperature", detail: t.thermalState.label)
            HStack(spacing: 20) {
                tempReadout("CPU", t.cpuCelsius)
                tempReadout("Battery", t.batteryCelsius)
            }
        }
    }

    private func tempReadout(_ title: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value.map { String(format: "%.1f°C", $0) } ?? "—")
                .font(.system(.title3, design: .rounded)).monospacedDigit()
        }
    }

    // MARK: - Helpers

    private func label(_ title: String, detail: String) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.medium))
            Spacer()
            Text(detail).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func color(for fraction: Double) -> Color {
        switch fraction {
        case ..<0.6: return .green
        case ..<0.85: return .yellow
        default: return .red
        }
    }
}
