import SwiftUI
import MacCleanerCore

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

    var tint: Color {
        switch self {
        case .overview:    return .blue
        case .smartCare:   return .purple
        case .cleanup:     return .green
        case .protection:  return .pink
        case .performance: return .orange
        case .applications: return .teal
        case .clutter:     return .indigo
        }
    }

    /// What it maps to in the reverse-engineered design.
    var reconstructionNote: String {
        switch self {
        case .overview:    return "Live system health (RAM, CPU, temperature)."
        case .smartCare:   return "SmartCareModule — orchestrates Cleanup + Protection + Performance."
        case .cleanup:     return "JunkCleanupModule — system junk, trash, mail caches."
        case .protection:  return "ProtectionModule — malware (Moonlock) + privacy."
        case .performance: return "PerformanceModule — login items, launch agents, maintenance, RAM."
        case .applications: return "ApplicationsModule — deep-clean uninstaller + updater."
        case .clutter:     return "OrganizeModule — large & old files, duplicates, media junk."
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let monitor = SystemMonitor(interval: 2.0)
    init() { monitor.start() }
}

@main
struct MacCleanerMainApp: App {
    @StateObject private var model = AppModel()
    @State private var selection: Module = .overview

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                List(Module.allCases, selection: $selection) { module in
                    HStack(spacing: 10) {
                        Image(systemName: module.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(module.tint.gradient, in: RoundedRectangle(cornerRadius: 7))
                        Text(module.rawValue)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                    .tag(module)
                }
                .listStyle(.sidebar)
                .navigationTitle("MacCleaner")
                .navigationSplitViewColumnWidth(min: 230, ideal: 240)
            } detail: {
                switch selection {
                case .overview:     OverviewView(monitor: model.monitor)
                case .smartCare:    SmartCareView()
                case .cleanup:      CleanupView()
                case .applications: ApplicationsView()
                case .clutter:      ClutterView()
                case .performance:  PerformanceView()
                case .protection:   ProtectionView()
                default:            PlaceholderView(module: selection)
                }
            }
            .frame(minWidth: 820, minHeight: 540)
        }
        .windowStyle(.titleBar)
    }
}

struct PlaceholderView: View {
    let module: Module
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: module.systemImage).font(.system(size: 44)).foregroundStyle(.secondary)
            Text(module.rawValue).font(.title2.weight(.semibold))
            Text(module.reconstructionNote)
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            Text("Not yet implemented").font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
