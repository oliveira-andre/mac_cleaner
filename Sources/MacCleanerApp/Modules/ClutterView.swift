import SwiftUI
import MacCleanerCore

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
        VStack(alignment: .leading, spacing: 14) {
            Text("My Clutter").font(.largeTitle.weight(.bold))
            Text("Large & old files and duplicates — OrganizeModule")
                .font(.callout).foregroundStyle(.secondary)

            if vm.scanning {
                Spacer(); ProgressView("Scanning Downloads, Documents, Desktop, Movies…")
                    .frame(maxWidth: .infinity); Spacer()
            } else if let report = vm.report {
                Picker("", selection: $tab) {
                    Text("Large & Old (\(bf.string(fromByteCount: Int64(report.largeOldBytes))))").tag(0)
                    Text("Duplicates (\(bf.string(fromByteCount: Int64(report.duplicateReclaimableBytes))))").tag(1)
                }
                .pickerStyle(.segmented).labelsHidden()

                if tab == 0 { largeOldList(report) } else { duplicatesList(report) }

                HStack {
                    if let msg = vm.statusMessage {
                        Text(msg).font(.callout).foregroundStyle(.green)
                    }
                    Spacer()
                    Button("Rescan") { vm.scan() }
                    Button(role: .destructive) { vm.clean() } label: {
                        Label("Move \(bf.string(fromByteCount: Int64(vm.selectedBytes(in: report)))) to Trash",
                              systemImage: "trash")
                    }.disabled(vm.selected.isEmpty)
                }
            } else {
                Spacer(); Button("Scan") { vm.scan() }.controlSize(.large).frame(maxWidth: .infinity); Spacer()
            }
        }
        .padding(24)
        .onAppear { if vm.report == nil && !vm.scanning { vm.scan() } }
    }

    private func largeOldList(_ report: ClutterReport) -> some View {
        List(report.largeOldFiles) { f in
            Toggle(isOn: Binding(get: { vm.selected.contains(f.url.path) },
                                 set: { _ in vm.toggle(f.url.path) })) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                        Text("\(f.ageDays) days since last use").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(bf.string(fromByteCount: Int64(f.sizeBytes))).font(.caption).monospacedDigit()
                }
            }
        }
    }

    private func duplicatesList(_ report: ClutterReport) -> some View {
        List {
            ForEach(report.duplicateGroups) { group in
                Section("\(group.count) copies · \(bf.string(fromByteCount: Int64(group.sizeEach))) each · \(bf.string(fromByteCount: Int64(group.reclaimableBytes))) reclaimable") {
                    ForEach(group.urls, id: \.path) { url in
                        Toggle(isOn: Binding(get: { vm.selected.contains(url.path) },
                                             set: { _ in vm.toggle(url.path) })) {
                            HStack {
                                Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                                if url == group.keeper {
                                    Text("keep").font(.caption2).foregroundStyle(.blue)
                                }
                                Spacer()
                                Text(url.deletingLastPathComponent().path)
                                    .font(.caption2).foregroundStyle(.tertiary)
                                    .lineLimit(1).truncationMode(.head)
                            }
                        }
                    }
                }
            }
        }
    }
}
