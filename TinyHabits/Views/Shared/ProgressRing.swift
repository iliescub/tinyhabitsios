import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let accent: Color
    var lineWidth: CGFloat = 5

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    Color.secondary.opacity(0.12),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Foreground progress with gradient
            Circle()
                .trim(from: 0, to: max(0, min(animatedProgress, 1)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            accent,
                            accent.adjustingBrightness(by: 0.15),
                            accent.adjustingBrightness(by: 0.08),
                            accent
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(0.3), radius: 4, x: 0, y: 2)

            // Subtle inner glow
            if animatedProgress > 0.01 {
                Circle()
                    .trim(from: 0, to: max(0, min(animatedProgress, 1)))
                    .stroke(
                        accent.opacity(0.2),
                        style: StrokeStyle(lineWidth: lineWidth - 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 2)
            }
        }
        .animation(DesignTokens.spring, value: animatedProgress)
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(DesignTokens.springBouncy) {
                animatedProgress = newValue
            }
        }
    }
}
