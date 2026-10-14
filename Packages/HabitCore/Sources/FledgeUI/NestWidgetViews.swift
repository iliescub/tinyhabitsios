import SwiftUI
import HabitCore

/// Home Screen widget content (docs/DESIGN.md §7, v2 in UX-17), shared by the widget extension and the app's
/// DEBUG widget gallery. The ring is supplied by the caller so the widget can wrap it in its interactive intent button.
public struct NestWidgetContent<Ring: View>: View {
    public enum Family: Sendable {
        /// `extraLarge` is the iPad-only size: the three habits side by side.
        case small, medium, large, extraLarge
    }

    public let family: Family
    public let snapshot: NestSnapshot
    public let date: Date
    public let isPro: Bool
    public let ring: (NestSnapshot.Item, CGFloat, CGFloat) -> Ring

    public init(
        family: Family, snapshot: NestSnapshot, date: Date, isPro: Bool,
        @ViewBuilder ring: @escaping (_ item: NestSnapshot.Item, _ size: CGFloat, _ lineWidth: CGFloat) -> Ring
    ) {
        self.family = family
        self.snapshot = snapshot
        self.date = date
        self.isPro = isPro
        self.ring = ring
    }

    public var body: some View {
        if snapshot.items.isEmpty {
            EmptyNestWidget()
        } else if family != .small && !isPro {
            ProWidget()
        } else {
            switch family {
            case .small: small
            case .medium: medium
            case .large: large
            case .extraLarge: extraLarge
            }
        }
    }

    private var isAllDone: Bool { snapshot.doneCount == snapshot.items.count }
    private var cards: [HabitCardModel] { snapshot.items.map(\.card) }

    // MARK: Small: the nest, two rings over one, with the count

    private var small: some View {
        let items = Array(snapshot.items.prefix(3))
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(items.prefix(2)) { ring($0, 54, 6) }
            }
            HStack(spacing: 8) {
                if items.count == 3 { ring(items[2], 54, 6) }
                VStack(spacing: 0) {
                    Text(snapshot.countText)
                        .font(.system(.title2, design: .rounded, weight: .heavy).monospacedDigit())
                        .foregroundStyle(FledgeTheme.Palette.ink)
                        .minimumScaleFactor(0.7)
                    Text(isAllDone ? "all done" : "done")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
                .frame(width: 54)
            }
        }
    }

    // MARK: Medium: one row per habit

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(snapshot.items.prefix(3)) { item in
                HStack(spacing: 10) {
                    ring(item, 34, 4.5)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.card.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FledgeTheme.Palette.ink)
                        WidgetValue(card: item.card, large: false)
                    }
                    Spacer(minLength: 0)
                    if item.card.isAuto {
                        Image(systemName: "heart.fill").font(.caption2).foregroundStyle(FledgeTheme.Palette.sky)
                    }
                }
            }
            Spacer(minLength: 0)
            footer
        }
    }

    // MARK: Large / StandBy: header with the day's status, then rows with the journey

    private var large: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ForEach(snapshot.items.prefix(3)) { item in
                HStack(spacing: 12) {
                    ring(item, 58, 7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.card.name).font(.headline).foregroundStyle(FledgeTheme.Palette.ink)
                        WidgetValue(card: item.card, large: true)
                        Text(item.card.flightText).font(.caption2).foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
            footer
        }
    }

    // MARK: Extra large (iPad): header, then the three habits as columns

    private var extraLarge: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            HStack(alignment: .top, spacing: 14) {
                ForEach(snapshot.items.prefix(3)) { item in
                    VStack(spacing: 10) {
                        ring(item, 92, 10)
                        VStack(spacing: 2) {
                            Text(item.card.name).font(.headline).foregroundStyle(FledgeTheme.Palette.ink)
                            WidgetValue(card: item.card, large: true)
                            Text(item.card.flightText)
                                .font(.caption2)
                                .foregroundStyle(FledgeTheme.Palette.ink2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FledgeTheme.Palette.ink.opacity(0.04), in: .rect(cornerRadius: 18, style: .continuous))
                }
            }
            Spacer(minLength: 0)
            footer
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.day.date().formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
                Text(TodaySummary.title(for: cards))
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(FledgeTheme.Palette.ink)
            }
            Spacer(minLength: 0)
            NestGlyph(rings: cards.map {
                NestGlyph.Ring(fraction: $0.progress.fraction, status: $0.progress.status, color: FledgeTheme.habitColor($0.colorKey))
            })
            .frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if isAllDone {
            HStack(spacing: 6) {
                FledgeBird(.sleeping, style: .glyph)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
                    .frame(width: 20)
                Text("Nest is quiet.")
                    .font(.caption2)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
        } else {
            FreshnessLine(snapshot: snapshot, now: date)
        }
    }
}

/// "4,210 / 6,000 steps" with the number emphasised.
struct WidgetValue: View {
    let card: HabitCardModel
    let large: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(card.metricText)
                .font(.system(large ? .headline : .subheadline, design: .rounded, weight: .heavy).monospacedDigit())
                .foregroundStyle(card.progress.status == .skipped ? FledgeTheme.Palette.ink2 : FledgeTheme.Palette.ink)
            if let goal = card.goalText {
                Text(goal)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// "Health updated 14 min ago" when Health data is older than 30 minutes.
public struct FreshnessLine: View {
    let snapshot: NestSnapshot
    let now: Date

    public init(snapshot: NestSnapshot, now: Date) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let updated = snapshot.oldestHealthUpdate, now.timeIntervalSince(updated) > 30 * 60 {
            Text("Health updated \(updated, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }
}

/// Pro-only widget sizes for free users; tapping opens the app.
public struct ProWidget: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 6) {
            FledgeBird(.flying, style: .tinted(FledgeTheme.Palette.sky)).frame(height: 34)
            Text("Fledge Pro")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(FledgeTheme.Palette.ink)
            Text("Every widget size, in the app")
                .font(.caption2)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }
}

/// No habits yet.
public struct EmptyNestWidget: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 6) {
            FledgeBird(.peeking, style: .glyph)
                .foregroundStyle(FledgeTheme.Palette.sky)
                .frame(height: 34)
            Text("Add a habit in Fledge")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }
}

/// Card colour with a hint of morning sky at the top.
public struct NestWidgetBackground: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [FledgeTheme.Palette.sky.opacity(0.12), FledgeTheme.Palette.card],
            startPoint: .top,
            endPoint: .center
        )
        .background(FledgeTheme.Palette.card)
    }
}
