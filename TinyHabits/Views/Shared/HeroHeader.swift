import SwiftUI

struct HeroHeader: View {
    let title: String
    let subtitle: String
    let accent: Color
    let quote: String?
    let imageName: String

    @State private var isAnimating = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Background with enhanced gradient
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusXL, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.adjustingBrightness(by: -0.08),
                            accent.adjustingBrightness(by: 0.08),
                            accent.adjustingBrightness(by: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle overlay pattern
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusXL, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.1), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 200
                    )
                )

            // Content
            HStack(spacing: DesignTokens.spacingM) {
                VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                    Text(subtitle)
                        .foregroundStyle(.white.opacity(0.95))
                        .font(.subheadline)
                        .lineLimit(2)

                    if let quote, !quote.isEmpty {
                        Text("\"\(quote)\"")
                            .font(.subheadline.italic())
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, DesignTokens.spacingXS)
                    }
                }
                .padding(.vertical, DesignTokens.spacingS)

                Spacer(minLength: 0)

                heroImage
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
                    .opacity(isAnimating ? 1.0 : 0.8)
            }
            .padding(DesignTokens.spacingXL)
        }
        .frame(height: 200)
        .shadow(color: accent.opacity(0.3), radius: DesignTokens.shadowRadiusLarge, y: DesignTokens.shadowYLarge)
        .shadow(color: accent.opacity(0.15), radius: 30, y: 15)
        .onAppear {
            withAnimation(DesignTokens.spring.delay(0.1)) {
                isAnimating = true
            }
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        } else {
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .padding(DesignTokens.spacingL)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous)
                        .fill(.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous)
                                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                        )
                )
        }
    }
}
