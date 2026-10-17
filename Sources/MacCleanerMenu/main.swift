import AppKit
import MacCleanerCore

// `--probe` prints one snapshot and exits — handy for verifying sensor reads
// without the GUI.
if CommandLine.arguments.contains("--probe") {
    let mem = MemoryMetrics.read()
    let temp = TemperatureMetrics.read()
    let gb = { (b: UInt64) in String(format: "%.2f GB", Double(b) / 1_073_741_824) }
    print("RAM used:    \(gb(mem.usedBytes)) / \(gb(mem.totalBytes)) (\(Int(mem.usedFraction * 100))%)")
    print("  wired:     \(gb(mem.wiredBytes))")
    print("  compressed:\(gb(mem.compressedBytes))")
    print("CPU temp:    \(temp.cpuCelsius.map { String(format: "%.1f°C", $0) } ?? "unavailable")")
    print("Battery temp:\(temp.batteryCelsius.map { String(format: "%.1f°C", $0) } ?? "unavailable")")
    print("Thermal:     \(temp.thermalState.label)")

    let storage = StorageMetrics.read()
    print("Storage:     \(gb(storage.usedBytes)) / \(gb(storage.totalBytes)) (\(Int(storage.usedFraction * 100))%)")
    let battery = BatteryMetrics.read()
    print("Battery:     \(battery.percent.map { "\($0)%" } ?? "n/a") — \(battery.state.rawValue)")

    // Two network samples a second apart to measure throughput.
    let sampler = NetworkSampler()
    _ = sampler.sample(); Thread.sleep(forTimeInterval: 1.0)
    let net = sampler.sample()
    func rate(_ b: UInt64) -> String { b >= 1_000_000 ? String(format: "%.1f MB/s", Double(b)/1_000_000) : String(format: "%.0f KB/s", Double(b)/1000) }
    print("Internet:    \(net.link.map { "online via \($0.rawValue)" } ?? "offline")")
    print("Wi-Fi:       \(net.ssid ?? (net.isConnected ? "connected" : "not connected"))  ↓\(rate(net.downBytesPerSec)) ↑\(rate(net.upBytesPerSec))")
    let devices = DeviceMetrics.read()
    print("Devices:     \(devices.isEmpty ? "none" : devices.map { "\($0.name) [\($0.kind)]" }.joined(separator: ", "))")
    exit(0)
}

// LSUIElement-equivalent menu-bar-only app (no Dock icon), matching how
// CleanMyMac ships its Menu login item (`LSUIElement = true`).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
