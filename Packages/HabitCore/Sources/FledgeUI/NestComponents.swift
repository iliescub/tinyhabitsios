import SwiftUI
import HabitCore

/// Three mini rings in a triangle: the whole day in one glyph, matching the small widget (UX-5).
public struct NestGlyph: View {
    public struct Ring: Sendable {
        public let fraction: Double
        public let status: EntryStatus
        public let color: Color

        public init(fraction: Double, status: EntryStatus, color: Color) {
            self.fraction = fraction
            self.status = status
            self.color = color
        }
    }

    public let rings: [Ring]

    public init(rings: [Ring]) {
        self.rings = rings
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let ring = side * 0.46
            let line = max(2.5, ring * 0.16)
            // Two on top, one centred below.
            let centres = [
                CGPoint(x: ring / 2, y: ring / 2),
                CGPoint(x: side - ring / 2, y: ring / 2),
                CGPoint(x: side / 2, y: side - ring / 2),
            ]
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    mini(index < rings.count ? rings[index] : nil, lineWidth: line)
                        .frame(width: ring - line, height: ring - line)
                        .position(centres[index])
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func mini(_ ring: Ring?, lineWidth: CGFloat) -> some View {
        if let ring {
            ZStack {
                Circle().stroke(ring.color.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: ring.status == .skipped ? 0 : max(0, min(ring.fraction, 1)))
                    .stroke(ring.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        } else {
            Circle().stroke(FledgeTheme.Palette.hairline, style: StrokeStyle(lineWidth: lineWidth * 0.6, dash: [2, 3]))
        }
    }
}

/// The last seven days, one dot per habit (UX-5). Missed days are empty dots, rest days rings.
public struct WeekStrip: View {
    public let model: WeekModel

    public init(model: WeekModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: FledgeTheme.Space.xs) {
            ForEach(model.days) { day in
                VStack(spacing: 6) {
                    Text(day.label)
                        .font(.caption2.weight(day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? FledgeTheme.Palette.ink : FledgeTheme.Palette.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 3) {
                        ForEach(Array(day.dots.enumerated()), id: \.offset) { _, dot in
                            DotView(dot: dot)
                        }
                    }
                }
                .padding(.vertical, FledgeTheme.Space.s)
                .frame(maxWidth: .infinity)
                .background {
                    if day.isToday {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(FledgeTheme.Palette.ink.opacity(0.06))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(day.accessibilityLabel))
            }
        }
        .padding(FledgeTheme.Space.s)
        .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Last seven days"))
    }

    private struct DotView: View {
        let dot: WeekModel.Dot

        var body: some View {
            let color = FledgeTheme.habitColor(dot.colorKey)
            Group {
                switch dot.state {
                case .done: Circle().fill(color)
                case .rest: Circle().strokeBorder(color, lineWidth: 1.3)
                case .open: Circle().fill(FledgeTheme.Palette.hairline)
                case .none: Color.clear
                }
            }
            .frame(width: 7, height: 7)
        }
    }
}

/// Day 1 → day 30 (can fly) → day 66 (automatic), with the bird riding the line (UX-7).
public struct JourneyTrack: View {
    public let model: JourneyModel
    public let color: Color

    public init(model: JourneyModel, color: Color) {
        self.model = model
        self.color = color
    }

    private let trackY: CGFloat = 36
    private let height: CGFloat = 84

    public var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 8
            let width = proxy.size.width - inset * 2
            let x = { (fraction: Double) in inset + width * CGFloat(fraction) }
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(FledgeTheme.Palette.hairline)
                    .frame(width: width, height: 6)
                    .position(x: inset + width / 2, y: trackY)
                Capsule()
                    .fill(color)
                    .frame(width: max(6, width * CGFloat(model.progress)), height: 6)
                    .position(x: inset + max(6, width * CGFloat(model.progress)) / 2, y: trackY)
                ForEach(Array(model.milestones.enumerated()), id: \.offset) { _, milestone in
                    Circle()
                        .fill(FledgeTheme.Palette.card)
                        .overlay {
                            Circle().strokeBorder(stroke(for: milestone), lineWidth: 3)
                        }
                        .frame(width: 14, height: 14)
                        .position(x: x(milestone.fraction), y: trackY)
                    VStack(spacing: 0) {
                        Text(milestone.title).font(.caption2.weight(.semibold)).foregroundStyle(FledgeTheme.Palette.ink)
                        Text(milestone.subtitle).font(.caption2).foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                    .fixedSize()
                    .position(x: labelX(milestone.fraction, inset: inset, width: width), y: trackY + 30)
                }
                FledgeBird(.flying, style: .tinted(color))
                    .frame(width: 28)
                    .position(x: min(inset + width - 10, max(inset + 10, x(model.progress))), y: trackY - 20)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(Text("\(model.headline). \(model.status)"))
    }

    private func stroke(for milestone: JourneyModel.Milestone) -> Color {
        if milestone.isGate { return FledgeTheme.Palette.gold }
        return milestone.isReached ? color : FledgeTheme.Palette.hairline
    }

    /// Keeps the first and last labels inside the card.
    private func labelX(_ fraction: Double, inset: CGFloat, width: CGFloat) -> CGFloat {
        switch fraction {
        case 0: inset + 18
        case 1: inset + width - 22
        default: inset + width * CGFloat(fraction)
        }
    }
}

/// Six feathers drift up 40 pt and fade over 0.8 s when a habit is done (UX-8). Nothing under Reduce Motion.
public struct FeatherBurst: View {
    public let trigger: Int
    public let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(trigger: Int, color: Color) {
        self.trigger = trigger
        self.color = color
    }

    private static let feathers: [(dx: CGFloat, rise: CGFloat, spin: Double, start: Double)] = [
        (-30, 44, -50, -30), (-16, 52, 30, -12), (-4, 40, -20, 8), (10, 50, 40, 20), (24, 42, -35, 34), (34, 36, 25, 50),
    ]

    public var body: some View {
        if reduceMotion {
            Color.clear.allowsHitTesting(false)
        } else {
            ZStack {
                ForEach(0..<Self.feathers.count, id: \.self) { index in
                    Ellipse()
                        .fill(index.isMultiple(of: 3) ? FledgeTheme.Palette.gold : color)
                        .frame(width: 5, height: 12)
                        .modifier(FeatherMotion(feather: Self.feathers[index], trigger: trigger))
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private struct FeatherMotion: ViewModifier {
        let feather: (dx: CGFloat, rise: CGFloat, spin: Double, start: Double)
        let trigger: Int

        func body(content: Content) -> some View {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, t in
                view
                    .rotationEffect(.degrees(feather.start + feather.spin * t))
                    .offset(x: feather.dx * (0.6 + 0.4 * t), y: -feather.rise * t)
                    .opacity(t > 0 && t < 1 ? 1 - t : 0)
            } keyframes: { _ in
                CubicKeyframe(1, duration: 0.8)
            }
        }
    }
}

/// A symbol on a soft square of its colour: template rows, settings rows (UX-9, UX-16). Scales with Dynamic Type.
public struct IconSquare: View {
    public let symbol: String
    public let color: Color
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 34

    public init(symbol: String, color: Color) {
        self.symbol = symbol
        self.color = color
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(.system(size: side * 0.48, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: side, height: side)
            .background(color.opacity(0.15), in: .rect(cornerRadius: side * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}
