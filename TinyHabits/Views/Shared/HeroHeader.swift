import SwiftUI

struct HeroHeader: View {
    let title: String
    let subtitle: String
    let accent: Color
    let quote: String?
    let imageName: String

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
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
                .shadow(color: accent.opacity(0.25), radius: 20, y: 12)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.subheadline)
                    if let quote, !quote.isEmpty {
                        Text("“\(quote)”")
                            .font(.subheadline.italic())
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 6)

                Spacer()

                heroImage
                    .frame(width: 140, height: 140)
            }
            .padding(20)
        }
        .frame(height: 200)
    }

    @ViewBuilder
    private var heroImage: some View {
        if UIImage(named: imageName) != nil {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 6)
        } else {
            Image(systemName: "figure.walk")
                .resizable()
                .scaledToFit()
                .padding(16)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}
