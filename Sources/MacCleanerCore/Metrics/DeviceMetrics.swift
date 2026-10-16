import Foundation
#if canImport(IOBluetooth)
import IOBluetooth
#endif

/// A connected external device — mounted volume or Bluetooth peripheral.
public struct ConnectedDevice: Sendable, Identifiable {
    public let name: String
    public let kind: String      // "Volume" | "Bluetooth"
    public let detail: String?   // size, etc.
    public var id: String { kind + ":" + name }
}

public enum DeviceMetrics {
    public static func read() -> [ConnectedDevice] {
        var devices: [ConnectedDevice] = []
        let fm = FileManager.default

        // External mounted volumes (USB drives, SD cards, external SSDs…).
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsInternalKey,
                                      .volumeTotalCapacityKey, .volumeIsBrowsableKey]
        if let vols = fm.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                           options: [.skipHiddenVolumes]) {
            for v in vols {
                guard let rv = try? v.resourceValues(forKeys: Set(keys)),
                      rv.volumeIsBrowsable == true,
                      rv.volumeIsInternal == false else { continue }
                let name = rv.volumeName ?? v.lastPathComponent
                let detail = rv.volumeTotalCapacity.map {
                    ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
                }
                devices.append(ConnectedDevice(name: name, kind: "Volume", detail: detail))
            }
        }

        // Bluetooth connected peripherals (best-effort).
        #if canImport(IOBluetooth)
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for d in paired where d.isConnected() {
                devices.append(ConnectedDevice(name: d.name ?? "Bluetooth device",
                                               kind: "Bluetooth", detail: nil))
            }
        }
        #endif

        return devices
    }
}
