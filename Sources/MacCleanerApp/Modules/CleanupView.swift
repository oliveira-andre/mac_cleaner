import SwiftUI
import MacCleanerCore

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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Cleanup").font(.largeTitle.weight(.bold))
                    Text("System junk, caches, logs, trash — JunkCleanupModule")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if let report = vm.report {
                    VStack(alignment: .trailing) {
                        Text(bf.string(fromByteCount: Int64(vm.selectedBytes)))
                            .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text("selected of \(bf.string(fromByteCount: Int64(report.totalBytes)))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if vm.scanning {
                Spacer(); ProgressView("Scanning for junk…").frame(maxWidth: .infinity); Spacer()
            } else if let report = vm.report {
                List {
                    ForEach(JunkCategory.allCases, id: \.self) { category in
                        let items = report.items.filter { $0.category == category }
                        if !items.isEmpty {
                            Section("\(category.rawValue) — \(bf.string(fromByteCount: Int64(items.reduce(0) { $0 + $1.sizeBytes })))") {
                                ForEach(items) { item in
                                    Toggle(isOn: Binding(
                                        get: { vm.selected.contains(item.id) },
                                        set: { _ in vm.toggle(item) }
                                    )) {
                                        HStack {
                                            Text(item.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                            Spacer()
                                            Text(bf.string(fromByteCount: Int64(item.sizeBytes)))
                                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                HStack {
                    if let msg = vm.statusMessage {
                        Text(msg).font(.callout).foregroundStyle(.green)
                    }
                    Spacer()
                    Button("Rescan") { vm.scan() }
                    Button(role: .destructive) { vm.clean() } label: {
                        Label("Clean \(bf.string(fromByteCount: Int64(vm.selectedBytes)))", systemImage: "trash")
                    }
                    .disabled(vm.selected.isEmpty)
                }
            } else {
                Spacer()
                Button("Scan") { vm.scan() }.controlSize(.large).frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(24)
        .onAppear { if vm.report == nil && !vm.scanning { vm.scan() } }
    }
}
