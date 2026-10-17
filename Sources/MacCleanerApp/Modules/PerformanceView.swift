import SwiftUI
import MacCleanerCore
import MacCleanerUI

@MainActor
final class PerformanceViewModel: ObservableObject {
    @Published var report: PerformanceReport?
    @Published var scanning = false
    @Published var statusMessage: String?

    func scan() {
        scanning = true
        Task.detached(priority: .userInitiated) {
            let result = PerformanceScanner().scan()
            await MainActor.run { self.report = result; self.scanning = false }
        }
    }

    func remove(_ item: StartupItem) {
        if item.needsPrivilege {
            statusMessage = "\(item.label): system item — needs the root helper."
            return
        }
        let outcome = FileRemover().moveToTrash(urls: [item.plistURL])
        statusMessage = outcome.trashed.isEmpty
            ? "Could not remove \(item.label)."
            : "Removed \(item.label) (plist moved to Trash)."
        scan()
    }

    func run(_ task: MaintenanceTask) {
        do {
            _ = try MaintenanceRunner().run(task)
            statusMessage = "\(task.title): done."
        } catch {
            statusMessage = "\(task.title): \(error)"
        }
    }
}

struct PerformanceView: View {
    @StateObject private var vm = PerformanceViewModel()
    private let bf: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .memory; return f }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            PageHeader(Module.performance) {
                if let report = vm.report {
                    HeaderStat(bf.string(fromByteCount: Int64(report.memory.usedBytes)),
                               caption: "of \(bf.string(fromByteCount: Int64(report.memory.totalBytes))) memory in use")
                }
            }

            if let report = vm.report {
                HStack(alignment: .top, spacing: Spacing.lg) {
                    startupList(report).frame(minWidth: 320)
                    maintenanceList.frame(minWidth: 280)
                }
                if let msg = vm.statusMessage { StatusLine(msg) }
            } else {
                LoadingState("Scanning startup items…")
            }
        }
        .padding(Spacing.xxl)
        .onAppear { if vm.report == nil { vm.scan() } }
    }

    private func startupList(_ report: PerformanceReport) -> some View {
        DataTable {
            DataTableHeader("Startup items") {
                Text("\(report.startupItems.count)").textStyle(.microCap).foregroundStyle(Palette.onDarkMuted)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(report.startupItems) { item in
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(item.label).lineLimit(1).truncationMode(.middle)
                                Text("\(item.kind.rawValue) · \(item.domain.rawValue)\(item.runAtLoad ? " · at login" : "")")
                                    .textStyle(.caption).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
                            }
                            Spacer(minLength: Spacing.md)
                            Button("Remove") { vm.remove(item) }.buttonStyle(.action(.ghost, size: .small))
                        }
                        .dataTableRow()
                    }
                }
            }
        }
    }

    private var maintenanceList: some View {
        DataTable {
            DataTableHeader("Maintenance")
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(MaintenanceTask.catalog) { task in
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(task.title)
                                Text(task.detail + (task.requiresRoot ? " (needs root helper)" : ""))
                                    .textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
                            }
                            Spacer(minLength: Spacing.md)
                            Button("Run") { vm.run(task) }
                                .buttonStyle(.action(.token, size: .small))
                                .disabled(task.requiresRoot)
                        }
                        .dataTableRow()
                    }
                }
            }
        }
    }
}
