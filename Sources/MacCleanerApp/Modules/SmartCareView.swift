import SwiftUI
import MacCleanerCore

@MainActor
final class SmartCareViewModel: ObservableObject {
    @Published var report: SmartCareReport?
    @Published var scanning = false
    @Published var summary: SmartCareRunner.Summary?

    func scan() {
        scanning = true
        summary = nil
        Task.detached(priority: .userInitiated) {
            let result = SmartCareScanner().scan()
            await MainActor.run { self.report = result; self.scanning = false }
        }
    }

    func run() {
        guard let report else { return }
        let result = SmartCareRunner().runAuto(report)
        summary = result
        scan()
    }
}

struct SmartCareView: View {
    @StateObject private var vm = SmartCareViewModel()
    private let bf: ByteCountFormatter = { let f = ByteCountFormatter(); f.countStyle = .file; return f }()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Smart Care").font(.largeTitle.weight(.bold))
            Text("One pass across Cleanup, Protection, Performance and My Clutter — SmartCareModule")
                .font(.callout).foregroundStyle(.secondary)

            if vm.scanning {
                Spacer(); ProgressView("Running Smart Care scan…").frame(maxWidth: .infinity); Spacer()
            } else if let report = vm.report {
                let cols = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: cols, spacing: 14) {
                    card("Cleanup", bf.string(fromByteCount: Int64(report.cleanup.autoSelectedBytes)),
                         "system junk", "trash", .green, auto: true)
                    card("Privacy", bf.string(fromByteCount: Int64(report.privacy.totalBytes)),
                         "\(report.privacy.items.count) browser items", "hand.raised", .blue, auto: true)
                    card("Protection", report.threatCount == 0 ? "Clean" : "\(report.threatCount) threats",
                         "malware scan", "shield", report.threatCount == 0 ? .green : .red, auto: true)
                    card("Performance", "\(report.startupCount)",
                         "startup items — review", "speedometer", .orange, auto: false)
                    card("Duplicates", bf.string(fromByteCount: Int64(report.duplicateReclaimBytes)),
                         "review in My Clutter", "square.stack.3d.up", .orange, auto: false)
                    card("Large & Old", bf.string(fromByteCount: Int64(report.largeOldBytes)),
                         "review in My Clutter", "doc", .orange, auto: false)
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Auto-clean: \(bf.string(fromByteCount: Int64(report.autoReclaimBytes)))")
                            .font(.headline)
                        if let s = vm.summary {
                            Text("Done — \(s.freedCount) items freed, \(s.threatsRemoved) threats removed" +
                                 (s.needsPrivilege > 0 ? ", \(s.needsPrivilege) need the root helper" : ""))
                                .font(.callout).foregroundStyle(.green)
                        } else {
                            Text("Orange cards need your review and aren't auto-run.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Rescan") { vm.scan() }
                    Button {
                        vm.run()
                    } label: {
                        Label("Run Smart Care", systemImage: "wand.and.stars")
                    }
                    .controlSize(.large).buttonStyle(.borderedProminent)
                }
            } else {
                Spacer()
                Button { vm.scan() } label: {
                    Label("Scan", systemImage: "wand.and.stars").padding(.horizontal)
                }.controlSize(.large).buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(24)
        .onAppear { if vm.report == nil && !vm.scanning { vm.scan() } }
    }

    private func card(_ title: String, _ value: String, _ subtitle: String,
                      _ icon: String, _ tint: Color, auto: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint).frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold))
                    if auto { Text("auto").font(.caption2).foregroundStyle(.secondary) }
                }
                Text(value).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }
}
