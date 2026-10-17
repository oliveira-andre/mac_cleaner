import SwiftUI

// Design tokens from DESIGN.md (Sentry-inspired). The whole app lives on the
// dark canvas: `surface-canvas-dark` behind everything, `surface-night` cards
// edged in a 1px `hairline-violet`, Rubik for UI copy, Monaco for paths, and
// `accent-lime` kept scarce — the keyword chip in each page title.
//
// Values are the DESIGN.md front-matter tokens. Not in the spec, and ours:
// `TextStyle.codeSm` (paths inside table rows) and the meter colors in
// `UsageBar`. The light-canvas tokens are left out — nothing here is light.

/// `{colors.*}`
public enum Palette {
    // Brand & accent
    public static let primary          = Color(hex: 0x150F23)
    public static let inkDeep          = Color(hex: 0x1F1633)
    public static let onPrimary        = Color(hex: 0xFFFFFF)
    public static let accentLime       = Color(hex: 0xC2EF4E)
    public static let accentPink       = Color(hex: 0xFA7FAA)
    public static let accentViolet     = Color(hex: 0x6A5FC1)
    public static let accentVioletDeep = Color(hex: 0x422082)
    public static let accentVioletMid  = Color(hex: 0x79628C)

    // Surface
    public static let canvas           = Color(hex: 0x1F1633)  // surface-canvas-dark
    public static let night            = Color(hex: 0x150F23)  // surface-night
    public static let pressLight       = Color(hex: 0xF0F0F0)
    public static let pressStronger    = Color(hex: 0xEFEFEF)
    public static let hairlineViolet   = Color(hex: 0x362D59)
    public static let hairlineCloud    = Color(hex: 0xE5E7EB)

    // Text
    public static let inkPress         = Color(hex: 0x1A1A1A)
    public static let onDarkMuted      = Color(hex: 0xBDB8C0)
    public static let onDarkFaint      = Color(hex: 0x3F3849)
}

/// `{spacing.*}` — 8px base unit.
public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let section: CGFloat = 96
}

/// `{rounded.*}`. `{rounded.full}` is `Capsule()`.
public enum Radius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 8
    public static let lg: CGFloat = 10
    public static let xl: CGFloat = 12
    public static let xxl: CGFloat = 18
}

/// A `{typography.*}` token: Rubik (or Monaco for code) at a fixed size,
/// weight, leading and tracking, optionally all-caps.
public struct TextStyle: Sendable {
    public let size: CGFloat
    public let weight: Int          // CSS weight
    public let lineHeight: CGFloat  // multiple of size
    public let tracking: CGFloat
    public let uppercase: Bool
    public let font: Font

    init(_ size: CGFloat, _ weight: Int, _ lineHeight: CGFloat, _ tracking: CGFloat = 0,
         uppercase: Bool = false, monospaced: Bool = false) {
        self.size = size
        self.weight = weight
        self.lineHeight = lineHeight
        self.tracking = tracking
        self.uppercase = uppercase
        self.font = monospaced ? .custom("Monaco", size: size) : Rubik.font(size: size, weight: weight)
    }

    /// SwiftUI only adds space between lines, so approximate CSS line-height
    /// on top of Rubik's natural ~1.2× leading.
    var lineSpacing: CGFloat { max(0, (lineHeight - 1.2) * size) }

    public static let headingXl      = TextStyle(30, 500, 1.20)
    public static let headingLg      = TextStyle(27, 500, 1.25)
    public static let headingMd      = TextStyle(24, 500, 1.25)
    public static let headingSm      = TextStyle(20, 600, 1.25)
    public static let bodyStrong     = TextStyle(16, 600, 1.50)
    public static let bodyMd         = TextStyle(16, 500, 1.50)
    public static let eyebrow        = TextStyle(15, 500, 1.40, uppercase: true)
    public static let buttonCap      = TextStyle(14, 700, 1.14, 0.2, uppercase: true)
    public static let buttonCapLight = TextStyle(14, 500, 1.29, 0.2, uppercase: true)
    public static let caption        = TextStyle(14, 400, 1.43)
    public static let microCap       = TextStyle(10, 600, 1.80, 0.25, uppercase: true)
    public static let code           = TextStyle(16, 400, 1.50, monospaced: true)
    public static let codeSm         = TextStyle(12, 400, 1.50, monospaced: true)
}

extension View {
    public func textStyle(_ style: TextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
            .textCase(style.uppercase ? .uppercase : nil)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
