import SwiftUI
import HabitCore

/// The progress ring used on cards, the detail screen and widgets (docs/DESIGN.md §6.1).
public struct HabitRing: View {
    public let fraction: Double
    public let status: EntryStatus
    public let color: Color
    public let symbol: String
    public var size: CGFloat
    public var lineWidth: CGFloat

    public init(
        fraction: Double,
        status: EntryStatus,
        color: Color,
        symbol: String,
        size: CGFloat = FledgeTheme.Ring.card,
        lineWidth: CGFloat = FledgeTheme.Ring.stroke
    ) {
        self.fraction = fraction
        self.status = status
        self.color = color
        self.symbol = symbol
        self.size = size
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(
                    color.opacity(0.18),
                    style: StrokeStyle(lineWidth: lineWidth, dash: status == .skipped ? [4, 6] : [])
                )
            Circle()
                .trim(from: 0, to: status == .skipped ? 0 : max(0, min(fraction, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if status == .done {
                Circle()
                    .fill(color.opacity(0.15))
                    .padding(lineWidth)
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: status == .done)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: fraction)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: status)
        .accessibilityHidden(true)
    }
}
