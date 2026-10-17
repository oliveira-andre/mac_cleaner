import CoreText
import Foundation
import SwiftUI

/// The bundled Rubik variable font (Resources/Fonts, SIL OFL). Weight is
/// dialed in through its `wght` axis (300–900). If the file can't be found,
/// every style falls back to the system font at the same size and weight, so
/// the hierarchy survives.
enum Rubik {
    static let fileName = "Rubik-Variable.ttf"

    // CTFontDescriptor is immutable and safe to share across threads.
    nonisolated(unsafe) private static let descriptor: CTFontDescriptor? = {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let candidates = [
            // Packaged .app — Scripts/make-*.sh copy Resources/Fonts into the bundle.
            Bundle.main.resourceURL?.appendingPathComponent("Fonts/\(fileName)"),
            // `swift run` from a checkout.
            repoRoot.appendingPathComponent("Resources/Fonts/\(fileName)"),
        ]
        for case let url? in candidates where FileManager.default.fileExists(atPath: url.path) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if let d = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first {
                return d
            }
        }
        return nil
    }()

    static func font(size: CGFloat, weight: Int) -> Font {
        guard let descriptor else { return .system(size: size, weight: systemWeight(weight)) }
        let d = CTFontDescriptorCreateCopyWithVariation(descriptor, 0x7767_6874 as CFNumber, CGFloat(weight))  // 'wght'
        return Font(CTFontCreateWithFontDescriptor(d, size, nil))
    }

    private static func systemWeight(_ weight: Int) -> Font.Weight {
        switch weight {
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        default:     return .bold
        }
    }
}
