import SwiftUI
import MacCleanerCore
import MacCleanerUI

@MainActor
final class ClutterViewModel: ObservableObject {
    @Published var report: ClutterReport?
    @Published var scanning = false
    @Published var selected: Set<String> = []       // file paths selected for removal
    @Published var statusMessage: String?

    func scan() {
        scanning = true
        statusMessage = nil
        Task.detached(priority: .userInitiated) {
            let result = OrganizeScanner().scan()
            await MainActor.run {
                self.report = result
                // Pre-select the removable copies in each duplicate group.
                self.selected = Set(result.duplicateGroups.flatMap { $0.removableDuplicates.map(\.path) })
                self.scanning = false
            }
        }
    }

    func toggle(_ path: String) {
        if selected.contains(path) { selected.remove(path) } else { selected.insert(path) }
    }

    func selectedBytes(in report: ClutterReport) -> UInt64 {
        var total: UInt64 = 0
        for f in report.largeOldFiles where selected.contains(f.url.path) { total += f.sizeBytes }
        for g in report.duplicateGroups {
            for u in g.urls where selected.contains(u.path) { total += g.sizeEach }
        }
        return total
    }

    func clean() {
        let urls = selected.map { URL(fileURLWithPath: $0) }
        let outcome = FileRemover().moveToTrash(urls: urls)
        statusMessage = "Moved \(outcome.trashed.count) item(s) to Trash."
        scan()
    }
}

struct ClutterView: View {
    @StateObject private var vm = ClutterViewModel()
    @State private var tab = 0

    private let bf: ByteCountFormatter = {
        let f = ByteCountFormatter(); f.countStyle = .file; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            PageHeader(Module.clutter)

            if vm.scanning {
                LoadingState("Scanning Downloads, Documents, Desktop, Movies…")
            } else if let report = vm.report {
                TokenTabs(selection: $tab, tabs: [
                    (0, "Large & Old · \(bf.string(fromByteCount: Int64(report.largeOldBytes)))"),
                    (1, "Duplicates · \(bf.string(fromByteCount: Int64(report.duplicateReclaimableBytes)))"),
                ])

                DataTable {
                    if tab == 0 { largeOldList(report) } else { duplicatesList(report) }
                }

                HStack(spacing: Spacing.md) {
                    if let msg = vm.statusMessage { StatusLine(msg, kind: .success) }
                    Spacer()
                    Button("Rescan") { vm.scan() }.buttonStyle(.action(.ghost))
                    Button { vm.clean() } label: {
                        Label("Move \(bf.string(fromByteCount: Int64(vm.selectedBytes(in: report)))) to Trash",
                              systemImage: "trash")
                    }
                    .buttonStyle(.action(.primary))
                    .disabled(vm.selected.isEmpty)
                }
            } else {
                EmptyState("My Clutter", message: "Find large, old and duplicate files in your home folders.") {
                    Button("Scan") { vm.scan() }.buttonStyle(.action(.primary))
                }
            }
        }
        .padding(Spacing.xxl)
        .onAppear { if vm.report == nil && !vm.scanning { vm.scan() } }
    }

    private func largeOldList(_ report: ClutterReport) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if report.largeOldFiles.isEmpty { emptyRow("No large or old files found.") }
                ForEach(report.largeOldFiles) { f in
                    Toggle(isOn: Binding(get: { vm.selected.contains(f.url.path) },
                                         set: { _ in vm.toggle(f.url.path) })) {
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(f.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                Text("\(f.ageDays) days since last use")
                                    .textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
                            }
                            Spacer(minLength: Spacing.md)
                            Text(bf.string(fromByteCount: Int64(f.sizeBytes)))
                                .textStyle(.caption).monospacedDigit().foregroundStyle(Palette.onDarkMuted)
                        }
                    }
                    .toggleStyle(.violetCheckbox)
                    .dataTableRow()
                }
            }
        }
    }

    private func duplicatesList(_ report: ClutterReport) -> some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                if report.duplicateGroups.isEmpty { emptyRow("No duplicates found.") }
                ForEach(report.duplicateGroups) { group in
                    Section {
                        ForEach(group.urls, id: \.path) { url in
                            Toggle(isOn: Binding(get: { vm.selected.contains(url.path) },
                                                 set: { _ in vm.toggle(url.path) })) {
                                HStack(spacing: Spacing.sm) {
                                    Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                    if url == group.keeper { Badge("keep", kind: .token) }
                                    Spacer(minLength: Spacing.md)
                                    Text(url.deletingLastPathComponent().path)
                                        .textStyle(.codeSm).foregroundStyle(Palette.onDarkMuted)
                                        .lineLimit(1).truncationMode(.head)
                                }
                            }
                            .toggleStyle(.violetCheckbox)
                            .dataTableRow()
                        }
                    } header: {
                        DataTableHeader("\(group.count) copies · \(bf.string(fromByteCount: Int64(group.sizeEach))) each") {
                            Text("\(bf.string(fromByteCount: Int64(group.reclaimableBytes))) reclaimable")
                                .textStyle(.microCap).foregroundStyle(Palette.onDarkMuted)
                        }
                    }
                }
            }
        }
    }

    private func emptyRow(_ message: String) -> some View {
        Text(message).textStyle(.caption).foregroundStyle(Palette.onDarkMuted).dataTableRow()
    }
}
