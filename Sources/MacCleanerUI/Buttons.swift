import SwiftUI

/// Buttons on the dark canvas. One filled CTA per screen: `.primary` is the
/// spec's `button-inverted` (white, ink text, level-1 lift); `.ghost` is
/// `button-ghost-on-dark`; `.token` is the mid-violet `button-violet-token`.
/// Labels are always uppercase caps with 0.2px tracking.
public struct ActionButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case primary, ghost, token }
    public enum Size: Sendable { case regular, small }

    let kind: Kind
    let size: Size

    public func makeBody(configuration: Configuration) -> some View {
        ActionButton(configuration: configuration, kind: kind, size: size)
    }
}

extension ButtonStyle where Self == ActionButtonStyle {
    public static func action(_ kind: ActionButtonStyle.Kind,
                              size: ActionButtonStyle.Size = .regular) -> ActionButtonStyle {
        ActionButtonStyle(kind: kind, size: size)
    }
}

private struct ActionButton: View {
    let configuration: ButtonStyle.Configuration
    let kind: ActionButtonStyle.Kind
    let size: ActionButtonStyle.Size
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: kind == .primary ? Radius.md : Radius.xl, style: .continuous)
        configuration.label
            .textStyle(kind == .token ? .buttonCapLight : .buttonCap)
            .lineLimit(1)
            .foregroundStyle(foreground)
            .padding(.horizontal, size == .regular ? Spacing.lg : Spacing.md)
            .padding(.vertical, size == .regular ? Spacing.md : 6)
            .background(background, in: shape)
            .overlay(shape.strokeBorder(kind == .token ? Palette.accentVioletDeep : .clear, lineWidth: 1))
            // Level 1 — the inverted button lifting off the dark canvas.
            .shadow(color: kind == .primary && isEnabled ? .black.opacity(0.08) : .clear, radius: 4, y: 2)
            .opacity(kind != .primary && !isEnabled ? 0.4 : 1)
            .contentShape(shape)
    }

    private var pressed: Bool { configuration.isPressed }

    private var foreground: Color {
        switch kind {
        case .primary:      return !isEnabled ? Palette.onDarkMuted : pressed ? Palette.inkPress : Palette.inkDeep
        case .ghost, .token: return Palette.onPrimary
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return !isEnabled ? Palette.hairlineCloud : pressed ? Palette.pressLight : Palette.onPrimary
        case .ghost:   return pressed ? Palette.accentVioletMid : Palette.onDarkFaint
        case .token:   return pressed ? Palette.accentVioletDeep : Palette.accentVioletMid
        }
    }
}

/// A tab in a `TokenTabs` row — the active one is a filled
/// `button-violet-token`, the rest are hairline outlines.
struct TokenTabStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
        configuration.label
            .textStyle(.buttonCapLight)
            .lineLimit(1)
            .foregroundStyle(isActive ? Palette.onPrimary : Palette.onDarkMuted)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(isActive ? Palette.accentVioletMid : configuration.isPressed ? Palette.onDarkFaint : .clear,
                        in: shape)
            .overlay(shape.strokeBorder(isActive ? Palette.accentVioletDeep : Palette.hairlineViolet, lineWidth: 1))
            .contentShape(shape)
    }
}

/// A sidebar nav item: muted text, with the active item on a deep-violet
/// `{rounded.md}` plate in white.
public struct SidebarItemStyle: ButtonStyle {
    let isActive: Bool

    public init(isActive: Bool) { self.isActive = isActive }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        configuration.label
            .textStyle(.bodyMd)
            .foregroundStyle(isActive ? Palette.onPrimary : Palette.onDarkMuted)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? Palette.accentVioletDeep : configuration.isPressed ? Palette.onDarkFaint : .clear,
                        in: shape)
            .contentShape(shape)
    }
}

/// A 16px checkbox: violet with a white tick when on, a mid-violet outline off.
public struct VioletCheckboxStyle: ToggleStyle {
    public func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: Spacing.md) {
                let box = RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                box.fill(configuration.isOn ? Palette.accentViolet : .clear)
                    .overlay(box.strokeBorder(configuration.isOn ? Palette.accentViolet : Palette.accentVioletMid,
                                              lineWidth: 1))
                    .overlay {
                        if configuration.isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(Palette.onPrimary)
                        }
                    }
                    .frame(width: 16, height: 16)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ToggleStyle where Self == VioletCheckboxStyle {
    public static var violetCheckbox: VioletCheckboxStyle { VioletCheckboxStyle() }
}

extension View {
    /// DESIGN.md reserves the focus ring for form fields, and this UI has none,
    /// so hide the system ring the first button gets when a window opens.
    /// Keyboard focus still moves; only the ring is hidden (macOS 14+).
    @ViewBuilder public func hidesFocusRing() -> some View {
        if #available(macOS 14.0, *) { focusEffectDisabled() } else { self }
    }
}
