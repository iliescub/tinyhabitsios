import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Design tokens from docs/DESIGN.md §3. Colours are contrast-checked: text tokens ≥ 4.5:1, graphic colours ≥ 3:1 on `card`.
public enum FledgeTheme {
    public enum Palette {
        public static let sky = Color(light: 0x4F8DFF, dark: 0x6FA3FF)
        public static let skyText = Color(light: 0x2563D6, dark: 0x8DB6FF)
        public static let dawn = Color(light: 0xFF5F45, dark: 0xFF8169)
        public static let gold = Color(light: 0xD0830E, dark: 0xFFC15E)
        public static let meadow = Color(light: 0x2CA874, dark: 0x4CCB94)
        public static let ink = Color(light: 0x1B2240, dark: 0xE9ECF8)
        public static let ink2 = Color(light: 0x5B6280, dark: 0xA3A9C2)
        public static let cloud = Color(light: 0xF7F5F2, dark: 0x0E1120)
        public static let card = Color(light: 0xFFFFFF, dark: 0x191D33)
        public static let hairline = Color(light: 0xE6E2DC, dark: 0x2A2F4A)
        /// Label colour on an ink-filled button (white in light mode, ink in dark mode where the fill is light).
        public static let onInk = Color(light: 0xFFFFFF, dark: 0x1B2240)
        /// The bird's beak and eye (docs/BRAND.md); the eye stays ink in both modes because the body stays white.
        public static let beak = Color(light: 0xFFB13D, dark: 0xFFC15E)
        public static let birdEye = Color(light: 0x1B2240, dark: 0x1B2240)
    }

    public enum Radius {
        public static let card: CGFloat = 24
        public static let tile: CGFloat = 18
    }

    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    public enum Ring {
        public static let card: CGFloat = 72
        public static let detail: CGFloat = 160
        public static let widget: CGFloat = 28
        public static let stroke: CGFloat = 8
    }

    /// Cards lift off the cloud background with a soft two-layer shadow in light mode and a hairline in dark mode (UX-1).
    public enum Elevation {
        public static let contactOpacity = 0.05
        public static let contactRadius: CGFloat = 1
        public static let contactY: CGFloat = 1
        public static let ambientOpacity = 0.07
        public static let ambientRadius: CGFloat = 10
        public static let ambientY: CGFloat = 6
    }

    /// Type ramp additions (UX-1). Dynamic Type styles only, so everything scales to AX5.
    public enum Typeface {
        /// Big rounded numbers: today's value, stats.
        public static let metric = Font.system(.title2, design: .rounded, weight: .heavy).monospacedDigit()
        /// Small numbers that sit next to a metric.
        public static let metricSmall = Font.system(.headline, design: .rounded, weight: .bold).monospacedDigit()
        /// Screen and card titles.
        public static let title = Font.system(.largeTitle, design: .rounded, weight: .heavy)
        /// Uppercase label above a title ("WEDNESDAY · 14 OCT"); pair with `.fledgeEyebrow()`.
        public static let eyebrow = Font.caption2.weight(.semibold)
        /// Goals, units, sources, freshness.
        public static let meta = Font.caption
    }

    public static let screenMargin: CGFloat = 20

    /// Habit colours in picker order. Slot defaults: 0 dawn, 1 sky, 2 meadow.
    public static let habitColorKeys = ["dawn", "sky", "meadow", "gold", "lilac", "teal", "rose", "slate"]

    public static func defaultColorKey(forSlot slot: Int) -> String {
        habitColorKeys.indices.contains(slot) ? habitColorKeys[slot] : "sky"
    }

    public static func habitColor(_ key: String) -> Color {
        switch key {
        case "dawn": Palette.dawn
        case "meadow": Palette.meadow
        case "gold": Palette.gold
        case "lilac": Color(light: 0x8E7CF0, dark: 0xA595F5)
        case "teal": Color(light: 0x1EA4A9, dark: 0x3CC4C9)
        case "rose": Color(light: 0xEF6396, dark: 0xF584AD)
        case "slate": Color(light: 0x6B7A99, dark: 0x8C9AB8)
        default: Palette.sky
        }
    }
}

// MARK: - Modifiers

/// Solid card surface with the elevation token. Never glass (docs/DESIGN.md §4).
public struct FledgeCardSurface: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                shape
                    .fill(FledgeTheme.Palette.card)
                    .shadow(
                        color: FledgeTheme.Palette.ink.opacity(colorScheme == .dark ? 0 : FledgeTheme.Elevation.contactOpacity),
                        radius: FledgeTheme.Elevation.contactRadius, y: FledgeTheme.Elevation.contactY
                    )
                    .shadow(
                        color: FledgeTheme.Palette.ink.opacity(colorScheme == .dark ? 0 : FledgeTheme.Elevation.ambientOpacity),
                        radius: FledgeTheme.Elevation.ambientRadius, y: FledgeTheme.Elevation.ambientY
                    )
            }
            .overlay {
                if colorScheme == .dark {
                    shape.strokeBorder(FledgeTheme.Palette.hairline, lineWidth: 1)
                }
            }
    }
}

/// Uppercase, tracked, secondary: the eyebrow line above a title.
public struct FledgeEyebrow: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(FledgeTheme.Typeface.eyebrow)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(FledgeTheme.Palette.ink2)
    }
}

extension View {
    /// A card on the cloud background: solid fill, soft shadow (light) or hairline (dark).
    public func fledgeCard(cornerRadius: CGFloat = FledgeTheme.Radius.card) -> some View {
        modifier(FledgeCardSurface(radius: cornerRadius))
    }

    public func fledgeEyebrow() -> some View {
        modifier(FledgeEyebrow())
    }
}

/// The primary call to action: an ink capsule (14 : 1 contrast), Liquid Glass prominent on iOS 26.
/// Ink replaced the blue fill so blue is free to mean Apple Health and links (docs/UI-REDESIGN.md, UX-1).
public struct FledgePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(FledgeTheme.Palette.onInk)
            .padding(.horizontal, FledgeTheme.Space.xl)
            .padding(.vertical, FledgeTheme.Space.m + 2)
            .background(FledgeTheme.Palette.ink.opacity(isEnabled ? 1 : 0.35), in: .capsule)
            .shadow(color: FledgeTheme.Palette.ink.opacity(0.18), radius: 8, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(.capsule)
    }
}

extension Color {
    /// A colour that switches between two sRGB hex values with the system appearance.
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#elseif canImport(AppKit)
extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
