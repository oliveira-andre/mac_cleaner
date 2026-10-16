import SwiftUI
import MacCleanerCore

@MainActor
final class ApplicationsViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var selected: InstalledApp?
    @Published var plan: UninstallPlan?
    @Published var scanning = false
    @Published var statusMessage: String?

    private let scanner = AppScanner()

    func loadApps() {
        apps = scanner.scan()
    }

    func scanLeftovers(for app: InstalledApp) {
        selected = app
        plan = nil
        scanning = true
        statusMessage = nil
        Task.detached(priority: .userInitiated) {
            // Build the fetcher inside the task (FileManager isn't Sendable);
            // `app` is Sendable so it crosses the boundary safely.
            let result = LeftoversFetcher().fetchLeftovers(for: app)
            await MainActor.run {
                self.plan = result
                self.scanning = false
            }
        }
    }

    func trashSelected() {
        guard let plan else { return }
        let outcome = FileRemover().moveToTrash(plan)
        var msg = "Moved \(outcome.trashed.count) item(s) to Trash."
        if !outcome.needsPrivilege.isEmpty {
            msg += " \(outcome.needsPrivilege.count) system-owned item(s) need the root helper."
        }
        statusMessage = msg
        if let app = selected { scanLeftovers(for: app) } // refresh
    }
}

struct ApplicationsView: View {
    @StateObject private var vm = ApplicationsViewModel()

    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter(); f.countStyle = .file; return f
    }()

    var body: some View {
        HSplitView {
            List(vm.apps, selection: Binding(
                get: { vm.selected?.id },
                set: { id in if let app = vm.apps.first(where: { $0.id == id }) { vm.scanLeftovers(for: app) } }
            )) { app in
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                    Text(app.bundleID).font(.caption2).foregroundStyle(.secondary)
                }.tag(app.id)
            }
            .frame(minWidth: 240)

            detail.frame(minWidth: 420)
        }
        .navigationTitle("Applications — Uninstaller")
        .onAppear { vm.loadApps() }
    }

    @ViewBuilder private var detail: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let app = vm.selected {
                Text(app.name).font(.title2.weight(.semibold))
                Text(app.bundleID).font(.callout).foregroundStyle(.secondary)

                if vm.scanning {
                    ProgressView("Scanning leftovers…")
                } else if let plan = vm.plan {
                    Text("Deep clean: \(plan.items.count) items · \(byteFormatter.string(fromByteCount: Int64(plan.totalBytes)))")
                        .font(.headline)
                    List(plan.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category.rawValue).font(.caption.weight(.medium))
                                Text(item.url.path).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Text(byteFormatter.string(fromByteCount: Int64(item.sizeBytes)))
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    Button(role: .destructive) { vm.trashSelected() } label: {
                        Label("Move all to Trash", systemImage: "trash")
                    }
                    if let msg = vm.statusMessage {
                        Text(msg).font(.callout).foregroundStyle(.green)
                    }
                }
            } else {
                Text("Select an app to deep-clean.").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
