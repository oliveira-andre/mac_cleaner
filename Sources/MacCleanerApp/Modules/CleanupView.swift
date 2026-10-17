import SwiftUI
import MacCleanerCore
import MacCleanerUI

@MainActor
final class CleanupViewModel: ObservableObject {
    @Published var report: CleanupReport?
    @Published var scanning = false
    @Published var selected: Set<String> = []
    @Published var statusMessage: String?

    func scan() {
        scanning = true
        statusMessage = nil
        Task.detached(priority: .userInitiated) {
            let result = CleanupScanner().scan()
            await MainActor.run {
                self.report = result
                // Pre-tick the auto-selectable categories (safe to clear).
                self.selected = Set(result.items.filter { $0.category.autoSelect }.map(\.id))
                self.scanning = false
            }
        }
    }

    var selectedBytes: UInt64 {
        guard let report else { return 0 }
        return report.items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    func toggle(_ item: JunkItem) {
        if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
    }

    func clean() {
        guard let report else { return }
        let urls = report.items.filter { selected.contains($0.id) }.map(\.url)
        let outcome = FileRemover().moveToTrash(urls: urls)
        statusMessage = "Moved \(outcome.trashed.count) item(s) to Trash."
        scan()
    }
}

struct CleanupView: View {
    @StateObject private var vm = CleanupViewModel()

    private let bf: ByteCountFormatter = {
        let f = ByteCountFormatter(); f.countStyle = .file; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            PageHeader(Module.cleanup) {
                if let report = vm.report {
                    HeaderStat(bf.string(fromByteCount: Int64(vm.selectedBytes)),
                               caption: "selected of \(bf.string(fromByteCount: Int64(report.totalBytes)))")
                }
            }

            if vm.scanning {
                LoadingState("Scanning for junk…")
            } else if let report = vm.report {
                DataTable {
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(JunkCategory.allCases, id: \.self) { category in
                                let items = report.items.filter { $0.category == category }
                                if !items.isEmpty {
                                    Section {
                                        ForEach(items) { item in row(item) }
                                    } header: {
                                        DataTableHeader(category.rawValue) {
                                            Text(bf.string(fromByteCount: Int64(items.reduce(0) { $0 + $1.sizeBytes })))
                                                .textStyle(.microCap).foregroundStyle(Palette.onDarkMuted)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                HStack(spacing: Spacing.md) {
                    if let msg = vm.statusMessage { StatusLine(msg, kind: .success) }
                    Spacer()
                    Button("Rescan") { vm.scan() }.buttonStyle(.action(.ghost))
                    Button { vm.clean() } label: {
                        Label("Clean \(bf.string(fromByteCount: Int64(vm.selectedBytes)))", systemImage: "trash")
                    }
                    .buttonStyle(.action(.primary))
                    .disabled(vm.selected.isEmpty)
                }
            } else {
                EmptyState("Cleanup", message: "Find caches, logs and other junk that's safe to clear.") {
                    Button("Scan") { vm.scan() }.buttonStyle(.action(.primary))
                }
            }
        }
        .padding(Spacing.xxl)
        .onAppear { if vm.report == nil && !vm.scanning { vm.scan() } }
    }

    private func row(_ item: JunkItem) -> some View {
        Toggle(isOn: Binding(
            get: { vm.selected.contains(item.id) },
            set: { _ in vm.toggle(item) }
        )) {
            HStack(spacing: Spacing.md) {
                Text(item.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: Spacing.md)
                Text(bf.string(fromByteCount: Int64(item.sizeBytes)))
                    .textStyle(.caption).monospacedDigit().foregroundStyle(Palette.onDarkMuted)
            }
        }
        .toggleStyle(.violetCheckbox)
        .dataTableRow()
    }
}
