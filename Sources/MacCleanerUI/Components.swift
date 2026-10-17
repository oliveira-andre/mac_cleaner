import SwiftUI

// MARK: - Page header

/// Module header on the dark canvas: a muted all-caps eyebrow, a `heading-xl`
/// title whose `highlight` word sits in the lime keyword chip, a caption
/// subtitle with an optional code chip, and an optional trailing view.
public struct PageHeader<Trailing: View>: View {
    let title: String
    let highlight: String?
    let eyebrow: String?
    let subtitle: String?
    let code: String?
    let trailing: Trailing

    public init(_ title: String, highlight: String? = nil, eyebrow: String? = nil,
                subtitle: String? = nil, code: String? = nil,
                @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.highlight = highlight
        self.eyebrow = eyebrow
        self.subtitle = subtitle
        self.code = code
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if let eyebrow {
                    Text(eyebrow).textStyle(.eyebrow).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
                }
                titleRow
                if subtitle != nil || code != nil {
                    HStack(spacing: Spacing.sm) {
                        if let subtitle {
                            Text(subtitle).textStyle(.caption).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
                        }
                        if let code { Badge(code, kind: .code) }
                    }
                }
            }
            Spacer(minLength: 0)
            trailing
        }
    }

    @ViewBuilder private var titleRow: some View {
        if let highlight, let range = title.range(of: highlight) {
            let before = title[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            let after = title[range.upperBound...].trimmingCharacters(in: .whitespaces)
            HStack(spacing: Spacing.sm) {
                if !before.isEmpty { titleText(before) }
                KeywordChip(highlight, style: .headingXl)
                if !after.isEmpty { titleText(after) }
            }
        } else {
            titleText(title)
        }
    }

    private func titleText(_ s: String) -> some View {
        Text(s).textStyle(.headingXl).foregroundStyle(Palette.onPrimary).lineLimit(1)
    }
}

extension PageHeader where Trailing == EmptyView {
    public init(_ title: String, highlight: String? = nil, eyebrow: String? = nil,
                subtitle: String? = nil, code: String? = nil) {
        self.init(title, highlight: highlight, eyebrow: eyebrow, subtitle: subtitle, code: code) { EmptyView() }
    }
}

/// `chip-lime-keyword` — a single word wrapped in electric lime, hugging the
/// cap height (no vertical padding). Keep it to one per screen.
public struct KeywordChip: View {
    let text: String
    let style: TextStyle

    public init(_ text: String, style: TextStyle) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .textStyle(style)
            .lineLimit(1)
            .foregroundStyle(Palette.inkDeep)
            .padding(.horizontal, style.size >= 24 ? Spacing.md : Spacing.sm)
            .background(Palette.accentLime, in: RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
    }
}

/// A header stat: white `heading-md` value over a muted caption, right-aligned.
public struct HeaderStat: View {
    let value: String
    let caption: String

    public init(_ value: String, caption: String) {
        self.value = value
        self.caption = caption
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            Text(value).textStyle(.headingMd).foregroundStyle(Palette.onPrimary).monospacedDigit().lineLimit(1)
            Text(caption).textStyle(.caption).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
        }
    }
}

/// A section title (`heading-sm`) with an optional trailing view.
public struct SectionTitle<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    public init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            Text(title).textStyle(.headingSm).foregroundStyle(Palette.onPrimary).lineLimit(1)
            Spacer(minLength: Spacing.sm)
            trailing
        }
    }
}

extension SectionTitle where Trailing == EmptyView {
    public init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

/// A rounded square carrying a glyph — deep violet by default, pink for danger.
public struct IconChip: View {
    let symbol: String
    let size: CGFloat
    let fill: Color
    let glyph: Color

    public init(_ symbol: String, size: CGFloat = 32,
                fill: Color = Palette.accentVioletDeep, glyph: Color = Palette.onPrimary) {
        self.symbol = symbol
        self.size = size
        self.fill = fill
        self.glyph = glyph
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(glyph)
            .frame(width: size, height: size)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }
}

// MARK: - Cards

extension View {
    /// A dark card on the canvas: `surface-night` fill, 1px `hairline-violet`
    /// edge, `{rounded.xl}` corners. Flat — depth on dark never comes from shadow.
    public func card(padding: CGFloat = Spacing.xl) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
        return self.padding(padding)
            .background(Palette.night, in: shape)
            .overlay(shape.strokeBorder(Palette.hairlineViolet, lineWidth: 1))
    }
}

// MARK: - Badges

/// Small labels. `token` is a mid-violet micro-cap tag, `danger` the pink
/// sticker variant, `code` the `pill-neutral-dark` chip set in Monaco.
public struct Badge: View {
    public enum Kind: Sendable { case token, danger, code }

    let text: String
    let kind: Kind

    public init(_ text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
        Text(text)
            .textStyle(kind == .code ? .codeSm : .microCap)
            .lineLimit(1)
            .foregroundStyle(kind == .danger ? Palette.inkDeep : Palette.onPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(background, in: shape)
            .overlay(shape.strokeBorder(kind == .code ? Palette.hairlineViolet : .clear, lineWidth: 1))
    }

    private var background: Color {
        switch kind {
        case .token:  return Palette.accentVioletMid
        case .danger: return Palette.accentPink
        case .code:   return Palette.night
        }
    }
}

// MARK: - Tabs

/// A row of `button-violet-token` tabs.
public struct TokenTabs<Value: Hashable>: View {
    @Binding var selection: Value
    let tabs: [(value: Value, title: String)]

    public init(selection: Binding<Value>, tabs: [(value: Value, title: String)]) {
        self._selection = selection
        self.tabs = tabs
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(tabs.indices, id: \.self) { i in
                Button(tabs[i].title) { selection = tabs[i].value }
                    .buttonStyle(TokenTabStyle(isActive: selection == tabs[i].value))
            }
        }
    }
}

// MARK: - Meters

/// A capsule meter on a `hairline-violet` track: violet fill, hot pink once
/// it's critical.
public struct UsageBar: View {
    let fraction: Double
    let tint: Color

    public init(_ fraction: Double, tint: Color? = nil) {
        self.fraction = min(max(fraction, 0), 1)
        self.tint = tint ?? UsageBar.tint(for: fraction)
    }

    /// Violet until it's critical: pink from 85%.
    public static func tint(for fraction: Double) -> Color {
        fraction < 0.85 ? Palette.accentViolet : Palette.accentPink
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairlineViolet)
                Capsule().fill(tint).frame(width: max(geo.size.width * fraction, fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .animation(.easeOut(duration: 0.2), value: fraction)
    }
}

// MARK: - Data table

/// Table chrome: a night card with a hairline-violet edge. Put a
/// `DataTableHeader` and a scroll of `.dataTableRow()` views inside.
public struct DataTable<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
        VStack(spacing: 0) { content }
            .background(Palette.night)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.hairlineViolet, lineWidth: 1))
    }
}

/// A micro-cap band on the canvas tone, ruled underneath. Also used as a
/// pinned section header inside a table.
public struct DataTableHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    public init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title).textStyle(.microCap).foregroundStyle(Palette.onDarkMuted).lineLimit(1)
            Spacer(minLength: Spacing.sm)
            trailing
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.inkDeep)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairlineViolet).frame(height: 1) }
    }
}

extension DataTableHeader where Trailing == EmptyView {
    public init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

extension View {
    /// A table row — white `body-md`, ruled in `hairline-violet`; selected rows
    /// sit on the faint on-dark fill.
    public func dataTableRow(selected: Bool = false) -> some View {
        self.textStyle(.bodyMd)
            .foregroundStyle(Palette.onPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(selected ? Palette.onDarkFaint : .clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairlineViolet).frame(height: 1) }
    }
}

// MARK: - States

/// Centered spinner + caption for in-flight scans.
public struct LoadingState: View {
    let message: String

    public init(_ message: String) { self.message = message }

    public var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView().controlSize(.small)
            Text(message).textStyle(.caption).foregroundStyle(Palette.onDarkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Centered card for empty / not-yet-scanned states.
public struct EmptyState<Action: View>: View {
    let title: String
    let message: String
    let action: Action

    public init(_ title: String, message: String, @ViewBuilder action: () -> Action) {
        self.title = title
        self.message = message
        self.action = action()
    }

    public var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(title).textStyle(.headingSm).foregroundStyle(Palette.onPrimary)
            Text(message).textStyle(.caption).foregroundStyle(Palette.onDarkMuted).multilineTextAlignment(.center)
            action.padding(.top, Spacing.md)
        }
        .frame(maxWidth: 420)
        .card(padding: Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension EmptyState where Action == EmptyView {
    public init(_ title: String, message: String) {
        self.init(title, message: message) { EmptyView() }
    }
}

/// A one-line outcome message: lime tick for success, pink warning for danger.
public struct StatusLine: View {
    public enum Kind: Sendable { case success, info, danger }

    let text: String
    let kind: Kind

    public init(_ text: String, kind: Kind = .info) {
        self.text = text
        self.kind = kind
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(text).textStyle(.caption).foregroundStyle(kind == .info ? Palette.onDarkMuted : Palette.onPrimary)
                .lineLimit(2)
        }
    }

    private var symbol: String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .info:    return "info.circle"
        case .danger:  return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch kind {
        case .success: return Palette.accentLime
        case .info:    return Palette.onDarkMuted
        case .danger:  return Palette.accentPink
        }
    }
}
