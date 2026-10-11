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
        public static let card: CGFloat = 64
        public static let detail: CGFloat = 160
        public static let widget: CGFloat = 28
        public static let stroke: CGFloat = 8
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
