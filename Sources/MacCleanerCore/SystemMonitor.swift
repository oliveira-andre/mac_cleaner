import Combine
import Foundation

/// A combined snapshot of everything the dashboard displays.
public struct HealthSnapshot: Sendable {
    public let memory: MemoryMetrics
    public let cpu: CPUMetrics
    public let temperature: TemperatureMetrics
    public let network: NetworkMetrics
    public let storage: StorageMetrics
    public let battery: BatteryMetrics
    public let devices: [ConnectedDevice]
    public let timestamp: Date
}

/// Periodic monitor that mirrors CleanMyMac's `PeriodicMonitor` role: it polls
/// the public/IOHID sources on a timer and publishes snapshots. Keeping it in
/// the core library (not the UI) means the main app and the menu can share it.
@MainActor
public final class SystemMonitor: ObservableObject {
    @Published public private(set) var snapshot: HealthSnapshot?

    private let cpuSampler = CPUSampler()
    private let networkSampler = NetworkSampler()
    private var timer: Timer?
    private let interval: TimeInterval

    public init(interval: TimeInterval = 2.0) {
        self.interval = interval
    }

    public func start() {
        stop()
        refresh()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() {
        snapshot = HealthSnapshot(
            memory: MemoryMetrics.read(),
            cpu: cpuSampler.sample(),
            temperature: TemperatureMetrics.read(),
            network: networkSampler.sample(),
            storage: StorageMetrics.read(),
            battery: BatteryMetrics.read(),
            devices: DeviceMetrics.read(),
            timestamp: Date()
        )
    }
}
