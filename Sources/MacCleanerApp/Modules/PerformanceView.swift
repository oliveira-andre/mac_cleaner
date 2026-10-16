import SwiftUI
import MacCleanerCore

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
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance").font(.largeTitle.weight(.bold))
            Text("Startup items + maintenance — PerformanceModule")
                .font(.callout).foregroundStyle(.secondary)

            if let report = vm.report {
                Text("Memory in use: \(bf.string(fromByteCount: Int64(report.memory.usedBytes))) of \(bf.string(fromByteCount: Int64(report.memory.totalBytes)))")
                    .font(.subheadline)

                HSplitView {
                    startupList(report)
                    maintenanceList
                }
                if let msg = vm.statusMessage {
                    Text(msg).font(.callout).foregroundStyle(.secondary)
                }
            } else {
                Spacer(); ProgressView("Scanning startup items…").frame(maxWidth: .infinity); Spacer()
            }
        }
        .padding(24)
        .onAppear { if vm.report == nil { vm.scan() } }
    }

    private func startupList(_ report: PerformanceReport) -> some View {
        VStack(alignment: .leading) {
            Text("Startup Items (\(report.startupItems.count))").font(.headline)
            List(report.startupItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label).lineLimit(1).truncationMode(.middle)
                        Text("\(item.kind.rawValue) · \(item.domain.rawValue)\(item.runAtLoad ? " · at login" : "")")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Remove") { vm.remove(item) }
                        .buttonStyle(.borderless).controlSize(.small)
                }
            }
        }.frame(minWidth: 320)
    }

    private var maintenanceList: some View {
        VStack(alignment: .leading) {
            Text("Maintenance").font(.headline)
            List(MaintenanceTask.catalog) { task in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                        Text(task.detail + (task.requiresRoot ? " (needs root helper)" : ""))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Run") { vm.run(task) }
                        .buttonStyle(.borderless).controlSize(.small)
                        .disabled(task.requiresRoot)
                }
            }
        }.frame(minWidth: 280)
    }
}
