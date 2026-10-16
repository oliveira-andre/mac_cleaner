// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [.macOS(.v13)],
    targets: [
        // C shim for the private IOHID thermal-sensor interface (CPU/SoC temperature).
        .target(
            name: "CSensors",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        // Shared XPC contract between the app and the root helper.
        .target(
            name: "IPCProtocol"
        ),
        // Reusable metrics + uninstaller engine.
        .target(
            name: "MacCleanerCore",
            dependencies: ["CSensors", "IPCProtocol"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("IOBluetooth"),
            ]
        ),
        // Root privileged helper daemon (installed via SMAppService).
        .executableTarget(
            name: "MacCleanerHelper",
            dependencies: ["IPCProtocol"]
        ),
        // The menu-bar ("top right") health addon.
        .executableTarget(
            name: "MacCleanerMenu",
            dependencies: ["MacCleanerCore"]
        ),
        // CLI for the Uninstaller deep-clean (dry-run by default).
        .executableTarget(
            name: "MacCleanerUninstall",
            dependencies: ["MacCleanerCore"]
        ),
        // The main app window (6-module sidebar).
        .executableTarget(
            name: "MacCleanerApp",
            dependencies: ["MacCleanerCore"]
        ),
    ]
)
