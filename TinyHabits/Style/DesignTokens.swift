import SwiftUI
import UIKit

enum DesignTokens {
    static let cornerRadius: CGFloat = 16
    static let shadow = Color.black.opacity(0.06)
    static let shadowRadius: CGFloat = 10
    static let shadowY: CGFloat = 6
    
    static func glassBackground(cornerRadius: CGFloat = cornerRadius) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: shadow, radius: shadowRadius, y: shadowY)
    }
    
    static func cardBackground(cornerRadius: CGFloat = cornerRadius) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: shadow, radius: shadowRadius, y: shadowY)
    }
    
//    static func gradientThemeBackground(themeManager: ThemeManager = ThemeManager()) -> LinearGradient {
//        LinearGradient(
//            colors: [
//                themeManager.complementary1AccentVariant,
//                themeManager.complementary2AccentVariant
//            ],
//            startPoint: .leading,
//            endPoint: .trailing
//        )
//    }
}
