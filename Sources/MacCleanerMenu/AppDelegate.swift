import AppKit
import MacCleanerCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor = SystemMonitor(interval: 2.0)

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent",
                                   accessibilityDescription: "MacCleaner")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        // Size to the content: the devices list grows and shrinks.
        let host = NSHostingController(rootView: MenuView(monitor: monitor) { [weak self] in self?.openMainApp() })
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
    }

    /// Opens MacCleaner.app — the copy built next to this one in build/ if
    /// there is one, otherwise whatever Launch Services knows by bundle id.
    private func openMainApp() {
        popover.performClose(nil)
        let workspace = NSWorkspace.shared
        let sibling = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("MacCleaner.app")
        guard let url = FileManager.default.fileExists(atPath: sibling.path)
                ? sibling : workspace.urlForApplication(withBundleIdentifier: "io.partnerfleet.maccleaner") else {
            NSSound.beep()
            return
        }
        workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            monitor.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
