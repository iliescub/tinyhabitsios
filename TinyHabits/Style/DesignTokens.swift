import SwiftUI
import UIKit

enum DesignTokens {
    // MARK: - Corner Radius
    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadius: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 20
    static let cornerRadiusXL: CGFloat = 28

    // MARK: - Shadows
    static let shadow = Color.black.opacity(0.06)
    static let shadowLight = Color.black.opacity(0.03)
    static let shadowMedium = Color.black.opacity(0.08)
    static let shadowHeavy = Color.black.opacity(0.12)
    static let shadowRadius: CGFloat = 10
    static let shadowRadiusLarge: CGFloat = 16
    static let shadowY: CGFloat = 6
    static let shadowYLarge: CGFloat = 8

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24

    // MARK: - Animations
    static let springResponse: Double = 0.5
    static let springDamping: Double = 0.7
    static let springBlendDuration: Double = 0.3

    static var spring: Animation {
        .spring(response: springResponse, dampingFraction: springDamping, blendDuration: springBlendDuration)
    }

    static var springBouncy: Animation {
        .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.25)
    }

    // MARK: - Glass & Modern Backgrounds
    static func glassBackground(cornerRadius: CGFloat = cornerRadius) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: shadow, radius: shadowRadius, y: shadowY)
    }

    static func cardBackground(cornerRadius: CGFloat = cornerRadius) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: shadow, radius: shadowRadius, y: shadowY)
    }

    static func elevatedCardBackground(cornerRadius: CGFloat = cornerRadius) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: shadowLight, radius: 4, y: 2)
            .shadow(color: shadowMedium, radius: shadowRadiusLarge, y: shadowYLarge)
    }
}
