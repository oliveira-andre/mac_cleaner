import SwiftUI
import MacCleanerCore
import MacCleanerUI

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
        VStack(alignment: .leading, spacing: Spacing.xl) {
            PageHeader(Module.protection)

            if vm.scanning {
                LoadingState("Scanning privacy data + malware rules…")
            } else {
                malwareSection
                privacySection
                if let msg = vm.statusMessage { StatusLine(msg) }
            }
        }
        .padding(Spacing.xxl)
        .onAppear { if vm.privacy == nil && !vm.scanning { vm.scan() } }
    }

    @ViewBuilder private var malwareSection: some View {
        if vm.malware.isEmpty {
            HStack(spacing: Spacing.md) {
                IconChip("checkmark.shield")
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("No known threats found").textStyle(.bodyStrong).foregroundStyle(Palette.onPrimary)
                    Text("Checked against the starter malware rule set.")
                        .textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
                }
                Spacer(minLength: 0)
            }
            .card(padding: Spacing.lg)
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionTitle("Threats") { Badge("\(vm.malware.count) found", kind: .danger) }
                DataTable {
                    ForEach(vm.malware) { finding in
                        HStack(spacing: Spacing.md) {
                            IconChip("exclamationmark.triangle.fill", size: 28,
                                     fill: Palette.accentPink, glyph: Palette.inkDeep)
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(finding.threatName)
                                Text(finding.matchedPath).textStyle(.codeSm).foregroundStyle(Palette.onDarkMuted)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                            Spacer(minLength: Spacing.md)
                            Button("Remove") { vm.quarantine(finding) }.buttonStyle(.action(.ghost, size: .small))
                        }
                        .dataTableRow()
                    }
                }
            }
        }
    }

    @ViewBuilder private var privacySection: some View {
        if let report = vm.privacy {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionTitle("Privacy") {
                    Button { vm.clearSelected() } label: {
                        Label("Clear \(bf.string(fromByteCount: Int64(vm.selectedBytes(report))))",
                              systemImage: "hand.raised")
                    }
                    .buttonStyle(.action(.primary))
                    .disabled(vm.selected.isEmpty)
                }
                DataTable {
                    DataTableHeader("Browser data") {
                        Text(bf.string(fromByteCount: Int64(report.totalBytes)))
                            .textStyle(.microCap).foregroundStyle(Palette.onDarkMuted)
                    }
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(report.items) { item in
                                Toggle(isOn: Binding(get: { vm.selected.contains(item.id) },
                                                     set: { _ in vm.toggle(item.id) })) {
                                    HStack(spacing: Spacing.md) {
                                        Text("\(item.browser) — \(item.category)").lineLimit(1)
                                        Spacer(minLength: Spacing.md)
                                        Text(bf.string(fromByteCount: Int64(item.sizeBytes)))
                                            .textStyle(.caption).monospacedDigit().foregroundStyle(Palette.onDarkMuted)
                                    }
                                }
                                .toggleStyle(.violetCheckbox)
                                .dataTableRow()
                            }
                        }
                    }
                }
            }
        }
    }
}
