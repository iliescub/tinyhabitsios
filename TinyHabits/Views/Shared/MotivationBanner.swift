import SwiftUI

struct MotivationBanner: View {
    let title: String
    let subtitle: String
    let accent: Color
    let quote: String?

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.adjustingBrightness(by: -0.06),
                            accent.adjustingBrightness(by: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: accent.opacity(0.25), radius: 18, y: 10)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(subtitle)
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.subheadline)
                if let quote {
                    Text("“\(quote)”")
                        .font(.subheadline.italic())
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(20)
        }
        .frame(height: 140)
    }
}
