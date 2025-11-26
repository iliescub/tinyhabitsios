import SwiftUI

struct DailyQuoteOverlay: View {
    let quote: String
    let onDismiss: (() -> Void)?

    var body: some View {
        ZStack {
            Color(.black)
                .opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Daily Quote")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(1)
                Text("“\(quote)”")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 32)
                Text("Keep showing up.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.1))
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            )
            .padding(32)
            .onTapGesture {
                onDismiss?()
            }
        }
        .accessibilityAddTraits(.isButton)
    }
}
