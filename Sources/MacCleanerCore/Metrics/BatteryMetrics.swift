import Foundation
import IOKit.ps

/// Battery charge + power state, from IOKit Power Sources (public API).
public struct BatteryMetrics: Sendable {
    public enum State: String, Sendable {
        case charging    = "Charging"
        case charged     = "Fully charged"
        case onBattery   = "On battery"
        case pluggedIn   = "Plugged in"     // desktop / no internal battery, on AC
        case unknown     = "Unknown"
    }

    public let hasBattery: Bool
    public let percent: Int?
    public let state: State

    public static func read() -> BatteryMetrics {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return BatteryMetrics(hasBattery: false, percent: nil, state: .pluggedIn)
        }
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                  (desc[kIOPSTypeKey as String] as? String) == (kIOPSInternalBatteryType as String)
            else { continue }

            let cur = desc[kIOPSCurrentCapacityKey as String] as? Int
            let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let percent = cur.map { max(0, min(100, Int(Double($0) / Double(maxCap) * 100))) }

            let isCharging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
            let isCharged = desc[kIOPSIsChargedKey as String] as? Bool ?? false
            let sourceState = desc[kIOPSPowerSourceStateKey as String] as? String
            let onAC = sourceState == (kIOPSACPowerValue as String)

            let state: State = isCharged ? .charged
                : isCharging ? .charging
                : onAC ? .pluggedIn
                : .onBattery
            return BatteryMetrics(hasBattery: true, percent: percent, state: state)
        }
        // No internal battery (desktop Mac).
        return BatteryMetrics(hasBattery: false, percent: nil, state: .pluggedIn)
    }
}
