import SwiftUI
import WidgetKit
import HabitCore

/// The progress ring used on cards, the detail screen and widgets (docs/DESIGN.md §6.1, ring v2 in docs/UI-REDESIGN.md UX-3).
///
/// The habit's symbol always stays in the centre so a done habit is still recognisable; state is a corner badge:
/// a check when done, a moon on a rest day, optionally a heart for Apple Health. Below 40 pt (widgets, Lock Screen)
/// there is no room for a badge, so done shows a check in the centre and rest days are dashed, as in v1.
public struct HabitRing: View {
    public enum Badge: Sendable, Equatable {
        case done, rest, health
    }

    public let fraction: Double
    public let status: EntryStatus
    public let color: Color
    public let symbol: String
    public var size: CGFloat
    public var lineWidth: CGFloat
    /// Shown when the status doesn't call for its own badge (pending or in progress). Only `.health` makes sense here.
    public var idleBadge: Badge?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Smallest ring that gets a corner badge.
    public nonisolated static let badgeMinimumSize: CGFloat = 40

    public init(
        fraction: Double,
        status: EntryStatus,
        color: Color,
        symbol: String,
        size: CGFloat = FledgeTheme.Ring.card,
        lineWidth: CGFloat = FledgeTheme.Ring.stroke,
        idleBadge: Badge? = nil
    ) {
        self.fraction = fraction
        self.status = status
        self.color = color
        self.symbol = symbol
        self.size = size
        self.lineWidth = lineWidth
        self.idleBadge = idleBadge
    }

    /// Which badge a ring shows; pure so it can be tested.
    public nonisolated static func badge(for status: EntryStatus, size: CGFloat, idle: Badge?) -> Badge? {
        guard size >= badgeMinimumSize else { return nil }
        switch status {
        case .done: return .done
        case .skipped: return .rest
        default: return idle
        }
    }

    /// The centre symbol; only rings too small for a badge swap in a check when done.
    public nonisolated static func centreSymbol(_ symbol: String, status: EntryStatus, size: CGFloat) -> String {
        status == .done && size < badgeMinimumSize ? "checkmark" : symbol
    }

    private var badge: Badge? { Self.badge(for: status, size: size, idle: idleBadge) }
    private var hasBadgeRoom: Bool { size >= Self.badgeMinimumSize }
    private var isRest: Bool { status == .skipped }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(
                    color.opacity(isRest ? 0.22 : 0.18),
                    style: StrokeStyle(lineWidth: lineWidth, dash: isRest && !hasBadgeRoom ? [4, 6] : [])
                )
            Circle()
                .trim(from: 0, to: isRest ? 0 : max(0, min(fraction, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
            if status == .done {
                Circle()
                    .fill(color.opacity(0.15))
                    .padding(lineWidth)
                    .transition(.opacity)
            }
            Image(systemName: Self.centreSymbol(symbol, status: status, size: size))
                .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                .foregroundStyle(isRest ? color.opacity(0.6) : color)
                .symbolRenderingMode(.hierarchical)
                .widgetAccentable()
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: status == .done)
                .symbolEffectsRemoved(reduceMotion)
            if let badge {
                RingBadge(badge: badge, color: color, diameter: max(18, size * 0.3))
                    .offset(badgeOffset)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .animation(ringAnimation, value: fraction)
        .animation(ringAnimation, value: status)
        .accessibilityHidden(true)
    }

    /// Bottom-trailing, centred on the ring's stroke at 45°.
    private var badgeOffset: CGSize {
        let radius = (size - lineWidth) / 2
        let d = radius * 0.7071
        return CGSize(width: d, height: d)
    }

    private var ringAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.85)
    }
}

/// Small circle on the ring: check (done), moon (rest), heart (Apple Health). Ringed in the card colour so it
/// reads as sitting on top of the stroke.
struct RingBadge: View {
    let badge: HabitRing.Badge
    let color: Color
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if badge != .done {
                Circle().strokeBorder(stroke, lineWidth: 1.5)
            }
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(glyph)
                .widgetAccentable()
        }
        .frame(width: diameter, height: diameter)
        .padding(2)
        .background(FledgeTheme.Palette.card, in: .circle)
    }

    private var symbol: String {
        switch badge {
        case .done: "checkmark"
        case .rest: "moon.fill"
        case .health: "heart.fill"
        }
    }

    private var fill: Color {
        badge == .done ? color : FledgeTheme.Palette.card
    }

    private var stroke: Color {
        badge == .health ? FledgeTheme.Palette.sky.opacity(0.5) : color.opacity(0.5)
    }

    private var glyph: Color {
        switch badge {
        case .done: .white
        case .rest: color
        case .health: FledgeTheme.Palette.sky
        }
    }
}
