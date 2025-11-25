import SwiftUI
import UIKit

enum AccentTheme: String, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case purple
    case pink
    case teal
    case yellow
    case indigo

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return Color.pink
        case .teal: return Color.teal
        case .yellow: return .yellow
        case .indigo: return Color.indigo
        }
    }
}

struct ThemeManager {
    @AppStorage("accentTheme") private var storedAccent: String = AccentTheme.blue.rawValue

    var accent: AccentTheme {
        get { AccentTheme(rawValue: storedAccent) ?? .blue }
        set { storedAccent = newValue.rawValue }
    }
    
    /// Secondary shade in the  range for gradient backgrounds.
    var AccentVariantGrad1: Color {
        accent.color.adjustingBrightness(by: -0.1)
    }
    /// Third shade in the complementary range for gradient backgrounds.
    var AccentVariantGrad2: Color {
        accent.color.adjustingBrightness(by: 0.1)
    }
    

    var complementaryAccent: Color {
        accent.color.complementary
    }

    /// Secondary shade in the complementary range for gradient backgrounds.
    var complementary1AccentVariant: Color {
        complementaryAccent.adjustingBrightness(by: -0.1)
    }
    /// Third shade in the complementary range for gradient backgrounds.
    var complementary2AccentVariant: Color {
        complementaryAccent.adjustingBrightness(by: 0.1)
    }
}

extension Color {
    /// Returns the complementary color by shifting the hue 180 degrees.
    var complementary: Color {
        #if os(iOS)
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            let shiftedHue = Double((hue + 0.5).truncatingRemainder(dividingBy: 1))
            return Color(
                hue: shiftedHue,
                saturation: Double(saturation),
                brightness: Double(brightness),
                opacity: Double(alpha)
            )
        }
        #endif
        return self
    }

    /// Returns a color with tweaked brightness while preserving hue/saturation.
    func adjustingBrightness(by delta: Double) -> Color {
        #if os(iOS)
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            let newBrightness = max(0, min(1, Double(brightness) + delta))
            let newHue = max(0, min(1, Double(hue) + delta/2))
            return Color(
                hue: newHue,
                saturation: Double(saturation),
                brightness: newBrightness,
                opacity: Double(alpha)
            )
        }
        #endif
        return self
    }
}
