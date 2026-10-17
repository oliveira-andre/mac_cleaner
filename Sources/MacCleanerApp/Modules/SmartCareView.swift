import SwiftUI
import MacCleanerCore
import MacCleanerUI

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
        VStack(alignment: .leading, spacing: Spacing.xl) {
            PageHeader(Module.smartCare)

            if vm.scanning {
                LoadingState("Running Smart Care scan…")
            } else if let report = vm.report {
                ScrollView {
                    let cols = [GridItem(.adaptive(minimum: 240), spacing: Spacing.lg)]
                    LazyVGrid(columns: cols, spacing: Spacing.lg) {
                        card("Cleanup", bf.string(fromByteCount: Int64(report.cleanup.autoSelectedBytes)),
                             "system junk", "trash", auto: true)
                        card("Privacy", bf.string(fromByteCount: Int64(report.privacy.totalBytes)),
                             "\(report.privacy.items.count) browser items", "hand.raised", auto: true)
                        card("Protection", report.threatCount == 0 ? "Clean" : "\(report.threatCount) threats",
                             "malware scan", "shield", auto: true, danger: report.threatCount > 0)
                        card("Performance", "\(report.startupCount)",
                             "startup items — review", "speedometer", auto: false)
                        card("Duplicates", bf.string(fromByteCount: Int64(report.duplicateReclaimBytes)),
                             "review in My Clutter", "square.stack.3d.up", auto: false)
                        card("Large & Old", bf.string(fromByteCount: Int64(report.largeOldBytes)),
                             "review in My Clutter", "doc", auto: false)
                    }
                }

                HStack(spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Auto-clean: \(bf.string(fromByteCount: Int64(report.autoReclaimBytes)))")
                            .textStyle(.headingSm).foregroundStyle(Palette.onPrimary).monospacedDigit()
                        if let s = vm.summary {
                            StatusLine("Done — \(s.freedCount) items freed, \(s.threatsRemoved) threats removed" +
                                       (s.needsPrivilege > 0 ? ", \(s.needsPrivilege) need the root helper" : ""),
                                       kind: .success)
                        } else {
                            Text("Cards without the AUTO tag need your review and aren't auto-run.")
                                .textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
                        }
                    }
                    Spacer()
                    Button("Rescan") { vm.scan() }.buttonStyle(.action(.ghost))
                    Button {
                        vm.run()
                    } label: {
                        Label("Run Smart Care", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.action(.primary))
                }
            } else {
                EmptyState("Smart Care", message: "Scan every module in one pass.") {
                    Button { vm.scan() } label: {
                        Label("Scan", systemImage: "wand.and.stars")
                    }.buttonStyle(.action(.primary))
                }
            }
        }
        .padding(Spacing.xxl)
        .onAppear { if vm.report == nil && !vm.scanning { vm.scan() } }
    }

    private func card(_ title: String, _ value: String, _ subtitle: String,
                      _ icon: String, auto: Bool, danger: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            IconChip(icon, fill: danger ? Palette.accentPink : auto ? Palette.accentVioletDeep : Palette.onDarkFaint,
                     glyph: danger ? Palette.inkDeep : Palette.onPrimary)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    Text(title).textStyle(.eyebrow).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
                    if auto { Badge("auto", kind: .token) }
                }
                Text(value).textStyle(.headingMd).foregroundStyle(Palette.onPrimary).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(subtitle).textStyle(.caption).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: Spacing.lg)
    }
}
