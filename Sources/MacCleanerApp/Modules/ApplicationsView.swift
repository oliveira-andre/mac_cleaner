import SwiftUI
import MacCleanerCore
import MacCleanerUI

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
        VStack(alignment: .leading, spacing: Spacing.xl) {
            PageHeader(Module.applications)
            HStack(alignment: .top, spacing: Spacing.lg) {
                appList.frame(width: 260)
                detail.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(Spacing.xxl)
        .onAppear { vm.loadApps() }
    }

    private var appList: some View {
        DataTable {
            DataTableHeader("Installed") {
                Text("\(vm.apps.count)").textStyle(.microCap).foregroundStyle(Palette.onDarkMuted)
            }
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.apps) { app in
                        Button { vm.scanLeftovers(for: app) } label: {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(app.name).lineLimit(1)
                                Text(app.bundleID).textStyle(.codeSm).foregroundStyle(Palette.onDarkMuted)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            .dataTableRow(selected: vm.selected?.id == app.id)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if let app = vm.selected {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .bottom, spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(app.name).textStyle(.headingSm).foregroundStyle(Palette.onPrimary).lineLimit(1)
                        Text(app.bundleID).textStyle(.codeSm).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let plan = vm.plan, !vm.scanning {
                        HeaderStat(byteFormatter.string(fromByteCount: Int64(plan.totalBytes)),
                                   caption: "\(plan.items.count) items to deep clean")
                    }
                }

                if vm.scanning {
                    LoadingState("Scanning leftovers…")
                } else if let plan = vm.plan {
                    DataTable {
                        DataTableHeader("Deep clean")
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(plan.items) { item in
                                    HStack(spacing: Spacing.md) {
                                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                                            Text(item.category.rawValue)
                                            Text(item.url.path).textStyle(.codeSm).foregroundStyle(Palette.onDarkMuted)
                                                .lineLimit(1).truncationMode(.middle)
                                        }
                                        Spacer(minLength: Spacing.md)
                                        Text(byteFormatter.string(fromByteCount: Int64(item.sizeBytes)))
                                            .textStyle(.caption).monospacedDigit().foregroundStyle(Palette.onDarkMuted)
                                    }
                                    .dataTableRow()
                                }
                            }
                        }
                    }
                    HStack(spacing: Spacing.md) {
                        if let msg = vm.statusMessage { StatusLine(msg, kind: .success) }
                        Spacer()
                        Button { vm.trashSelected() } label: {
                            Label("Move all to Trash", systemImage: "trash")
                        }
                        .buttonStyle(.action(.primary))
                    }
                }
            }
        } else {
            EmptyState("Pick an app", message: "Select an app to find everything it left behind.")
        }
    }
}
