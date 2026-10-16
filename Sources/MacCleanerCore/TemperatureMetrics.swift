import CSensors
import Foundation

/// Temperature readings. CPU/SoC comes from the private IOHID thermal-sensor
/// interface (see CSensors); battery from IOKit AppleSmartBattery. Either can
/// be `nil` on hardware that doesn't expose it (and CPU temp on some Apple
/// Silicon configs). `ProcessInfo.thermalState` is the always-available
/// fallback indicator.
public struct TemperatureMetrics: Sendable {
    public let cpuCelsius: Double?
    public let batteryCelsius: Double?
    public let thermalState: ProcessInfo.ThermalState

    public static func read() -> TemperatureMetrics {
        let cpu = cs_cpu_temperature_celsius()
        let battery = cs_battery_temperature_celsius()
        return TemperatureMetrics(
            cpuCelsius: cpu > 0 ? cpu : nil,
            batteryCelsius: battery > 0 ? battery : nil,
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }
}

extension ProcessInfo.ThermalState {
    public var label: String {
        switch self {
        case .nominal:  return "Normal"
        case .fair:     return "Fair"
        case .serious:  return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
