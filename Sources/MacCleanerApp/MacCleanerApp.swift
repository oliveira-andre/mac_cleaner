import SwiftUI
import MacCleanerCore
import MacCleanerUI

/// The six top-level modules, mirroring CleanMyMac 5's sidebar.
enum Module: String, CaseIterable, Identifiable {
    case overview    = "Overview"
    case smartCare   = "Smart Care"
    case cleanup     = "Cleanup"
    case protection  = "Protection"
    case performance = "Performance"
    case applications = "Applications"
    case clutter     = "My Clutter"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview:    return "gauge.with.dots.needle.33percent"
        case .smartCare:   return "wand.and.stars"
        case .cleanup:     return "trash.fill"
        case .protection:  return "shield.fill"
        case .performance: return "speedometer"
        case .applications: return "app.badge.fill"
        case .clutter:     return "square.stack.3d.up.fill"
        }
    }

    // MARK: Page header

    var title: String { self == .overview ? "System Health" : rawValue }

    /// The word wrapped in the lime keyword chip.
    var highlight: String {
        switch self {
        case .overview:  return "Health"
        case .smartCare: return "Care"
        case .clutter:   return "Clutter"
        default:         return rawValue
        }
    }

    var eyebrow: String {
        switch self {
        case .overview:    return "Live · every 2s"
        case .smartCare:   return "One-pass scan"
        case .cleanup:     return "System junk"
        case .protection:  return "Privacy + malware"
        case .performance: return "Startup + maintenance"
        case .applications: return "Uninstaller"
        case .clutter:     return "Organize"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:    return "RAM, CPU, storage, network, battery, temperature"
        case .smartCare:   return "Cleanup, Protection, Performance and My Clutter at once"
        case .cleanup:     return "Caches, logs, saved state, trash, Xcode data"
        case .protection:  return "Browser privacy data + a starter malware rule set"
        case .performance: return "Login items, launch agents, maintenance tasks"
        case .applications: return "Deep-clean an app and its leftovers"
        case .clutter:     return "Large & old files and exact duplicates"
        }
    }

    /// What it maps to in the reverse-engineered design.
    var reconstructs: String {
        switch self {
        case .overview:    return "HealthMonitor"
        case .smartCare:   return "SmartCareModule"
        case .cleanup:     return "JunkCleanupModule"
        case .protection:  return "ProtectionModule"
        case .performance: return "PerformanceModule"
        case .applications: return "ApplicationsModule"
        case .clutter:     return "OrganizeModule"
        }
    }
}

extension PageHeader {
    init(_ module: Module, @ViewBuilder trailing: () -> Trailing) {
        self.init(module.title, highlight: module.highlight, eyebrow: module.eyebrow,
                  subtitle: module.subtitle, code: module.reconstructs, trailing: trailing)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(_ module: Module) {
        self.init(module) { EmptyView() }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let monitor = SystemMonitor(interval: 2.0)
    init() { monitor.start() }
}

/// Closing the window quits the app. Without this a WindowGroup app keeps
/// running window-less in the Dock, and the menu's "Open MacCleaner"
/// (`NSWorkspace.openApplication`) just activates it — no window comes back.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct MacCleanerMainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @State private var selection: Module = .overview

    var body: some Scene {
        WindowGroup {
            HStack(spacing: 0) {
                Sidebar(selection: $selection)
                Rectangle().fill(Palette.hairlineViolet).frame(width: 1).ignoresSafeArea()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.canvas.ignoresSafeArea())
            }
            .frame(minWidth: 900, minHeight: 600)
            .preferredColorScheme(.dark)
            .hidesFocusRing()
        }
        .windowStyle(.hiddenTitleBar)
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .overview:     OverviewView(monitor: model.monitor)
        case .smartCare:    SmartCareView()
        case .cleanup:      CleanupView()
        case .applications: ApplicationsView()
        case .clutter:      ClutterView()
        case .performance:  PerformanceView()
        case .protection:   ProtectionView()
        }
    }
}

/// Night-toned sidebar: app icon + wordmark, then one nav item per module.
struct Sidebar: View {
    @Binding var selection: Module

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                // The bundle's AppIcon.icns (Scripts/make-icon.swift). Under
                // `swift run` there's no bundle, so this is the generic app icon.
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                Text("MacCleaner").textStyle(.headingSm).foregroundStyle(Palette.onPrimary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)

            ForEach(Module.allCases) { module in
                Button { selection = module } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: module.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 20)
                        Text(module.rawValue).lineLimit(1)
                    }
                }
                .buttonStyle(SidebarItemStyle(isActive: selection == module))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
        .frame(width: 232)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.night.ignoresSafeArea())
    }
}
