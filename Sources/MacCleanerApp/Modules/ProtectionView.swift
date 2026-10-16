import SwiftUI
import MacCleanerCore

@MainActor
final class ProtectionViewModel: ObservableObject {
    @Published var privacy: PrivacyReport?
    @Published var malware: [MalwareFinding] = []
    @Published var scanning = false
    @Published var selected: Set<String> = []
    @Published var statusMessage: String?

    func scan() {
        scanning = true
        statusMessage = nil
        Task.detached(priority: .userInitiated) {
            let p = PrivacyScanner().scan()
            let m = MalwareScanner().scan()
            await MainActor.run {
                self.privacy = p
                self.malware = m
                self.selected = Set(p.items.map(\.id))   // pre-select all privacy items
                self.scanning = false
            }
        }
    }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    func selectedBytes(_ report: PrivacyReport) -> UInt64 {
        report.items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.sizeBytes }
    }

    func clearSelected() {
        guard let privacy else { return }
        let urls = privacy.items.filter { selected.contains($0.id) }.map(\.url)
        let outcome = FileRemover().moveToTrash(urls: urls)
        statusMessage = "Cleared \(outcome.trashed.count) privacy item(s). Quit browsers first for best results."
        scan()
    }

    func quarantine(_ finding: MalwareFinding) {
        let outcome = FileRemover().moveToTrash(urls: [URL(fileURLWithPath: finding.matchedPath)])
        statusMessage = outcome.trashed.isEmpty
            ? "\(finding.threatName): needs the root helper to remove."
            : "\(finding.threatName): moved to Trash."
        scan()
    }
}

struct ProtectionView: View {
    @StateObject private var vm = ProtectionViewModel()
    private let bf: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .file; return f }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Protection").font(.largeTitle.weight(.bold))
            Text("Privacy + malware — ProtectionModule (starter rule set)")
                .font(.callout).foregroundStyle(.secondary)

            if vm.scanning {
                Spacer(); ProgressView("Scanning privacy data + malware rules…").frame(maxWidth: .infinity); Spacer()
            } else {
                malwareSection
                privacySection
                if let msg = vm.statusMessage {
                    Text(msg).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .onAppear { if vm.privacy == nil && !vm.scanning { vm.scan() } }
    }

    @ViewBuilder private var malwareSection: some View {
        if vm.malware.isEmpty {
            Label("No known threats found", systemImage: "checkmark.shield")
                .font(.headline).foregroundStyle(.green)
        } else {
            Text("Threats (\(vm.malware.count))").font(.headline).foregroundStyle(.red)
            ForEach(vm.malware) { finding in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.threatName).font(.subheadline.weight(.medium))
                        Text(finding.matchedPath).font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button("Remove") { vm.quarantine(finding) }.controlSize(.small)
                }
            }
        }
    }

    @ViewBuilder private var privacySection: some View {
        if let report = vm.privacy {
            HStack {
                Text("Privacy — \(bf.string(fromByteCount: Int64(report.totalBytes)))").font(.headline)
                Spacer()
                Button(role: .destructive) { vm.clearSelected() } label: {
                    Label("Clear \(bf.string(fromByteCount: Int64(vm.selectedBytes(report))))", systemImage: "hand.raised")
                }.disabled(vm.selected.isEmpty)
            }
            List(report.items) { item in
                Toggle(isOn: Binding(get: { vm.selected.contains(item.id) },
                                     set: { _ in vm.toggle(item.id) })) {
                    HStack {
                        Text("\(item.browser) — \(item.category)")
                        Spacer()
                        Text(bf.string(fromByteCount: Int64(item.sizeBytes)))
                            .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
