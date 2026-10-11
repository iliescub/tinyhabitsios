import AppIntents
import SwiftUI
import WidgetKit
import HabitCore
import FledgeUI

// MARK: - Home Screen and StandBy (docs/DESIGN.md §7)

struct NestWidget: Widget {
    static let kind = "com.smartapps.TinyHabits.nest"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NestProvider()) { entry in
            NestWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Your nest")
        .description("Today's three habits. Tap a ring to mark a tap-to-log habit done.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct NestWidgetView: View {
    let entry: NestEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.snapshot.items.isEmpty {
            EmptyNestView()
        } else if family != .systemSmall && !entry.isPro {
            ProWidgetView()
        } else {
            switch family {
            case .systemSmall: SmallNestView(snapshot: entry.snapshot)
            case .systemLarge: LargeNestView(snapshot: entry.snapshot, date: entry.date)
            default: MediumNestView(snapshot: entry.snapshot, date: entry.date)
            }
        }
    }
}

/// Three rings arranged as a nest, count in the middle.
struct SmallNestView: View {
    let snapshot: NestSnapshot

    var body: some View {
        let items = Array(snapshot.items.prefix(3))
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                ForEach(items.prefix(2)) { RingButton(item: $0, size: 52) }
            }
            HStack(spacing: 10) {
                if items.count == 3 { RingButton(item: items[2], size: 52) }
                Text(snapshot.countText)
                    .font(.title3.bold().monospacedDigit())
                    .fontDesign(.rounded)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                    .frame(width: 52)
            }
        }
    }
}

struct MediumNestView: View {
    let snapshot: NestSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(snapshot.items.prefix(3)) { item in
                HStack(spacing: 10) {
                    RingButton(item: item, size: 30, lineWidth: 4)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.card.name).font(.subheadline.weight(.semibold)).foregroundStyle(FledgeTheme.Palette.ink)
                        Text(item.card.valueText).font(.caption.monospacedDigit()).foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                    Spacer(minLength: 0)
                    if item.card.isAuto {
                        Image(systemName: "heart.fill").font(.caption2).foregroundStyle(FledgeTheme.Palette.skyText)
                    }
                }
            }
            Spacer(minLength: 0)
            FreshnessLabel(snapshot: snapshot, now: date)
        }
    }
}

struct LargeNestView: View {
    let snapshot: NestSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(snapshot.day.date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(FledgeTheme.Palette.ink)
            ForEach(snapshot.items.prefix(3)) { item in
                HStack(spacing: 14) {
                    RingButton(item: item, size: 56, lineWidth: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.card.name).font(.headline).foregroundStyle(FledgeTheme.Palette.ink)
                        Text(item.card.valueText).font(.subheadline.monospacedDigit()).foregroundStyle(FledgeTheme.Palette.ink2)
                        Text(item.card.flightText).font(.caption).foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
            FreshnessLabel(snapshot: snapshot, now: date)
        }
    }
}

/// A ring that toggles done for tap-to-log habits; Health habits open the app instead.
struct RingButton: View {
    let item: NestSnapshot.Item
    var size: CGFloat
    var lineWidth: CGFloat = 6

    var body: some View {
        let ring = HabitRing(
            fraction: item.card.progress.fraction,
            status: item.card.progress.status,
            color: FledgeTheme.habitColor(item.card.colorKey),
            symbol: item.card.progress.status == .done ? "checkmark" : item.card.symbol,
            size: size,
            lineWidth: lineWidth
        )
        if item.card.isAuto {
            ring
        } else {
            Button(intent: ToggleHabitIntent(habit: HabitEntity(id: item.id, name: item.card.name, symbol: item.card.symbol))) {
                ring
            }
            .buttonStyle(.plain)
        }
    }
}

/// "updated 14 min ago" when Health data is older than 30 minutes.
struct FreshnessLabel: View {
    let snapshot: NestSnapshot
    let now: Date

    var body: some View {
        if let updated = snapshot.oldestHealthUpdate, now.timeIntervalSince(updated) > 30 * 60 {
            Text("Health updated \(updated, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }
}

/// Shown in Pro-only widget slots for free users; tapping opens the app.
struct ProWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "bird.fill").font(.title2).foregroundStyle(FledgeTheme.Palette.dawn)
            Text("Fledge Pro")
                .font(.caption.bold())
                .foregroundStyle(FledgeTheme.Palette.ink)
            Text("Unlock in the app")
                .font(.caption2)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }
}

struct EmptyNestView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "bird").font(.title2).foregroundStyle(FledgeTheme.Palette.sky)
            Text("Add a habit in Fledge")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }
}

struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [FledgeTheme.Palette.sky.opacity(0.10), FledgeTheme.Palette.card],
            startPoint: .top,
            endPoint: .center
        )
        .background(FledgeTheme.Palette.card)
    }
}

// MARK: - Lock Screen

struct NestLockScreenWidget: Widget {
    static let kind = "com.smartapps.TinyHabits.nestLockScreen"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NestProvider()) { entry in
            NestLockScreenView(snapshot: entry.snapshot, isPro: entry.isPro)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Nest summary")
        .description("Three mini rings or one line of progress.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

struct NestLockScreenView: View {
    let snapshot: NestSnapshot
    @Environment(\.widgetFamily) private var family

    var isPro = true

    var body: some View {
        if !isPro {
            Label("Fledge Pro", systemImage: "bird")
        } else if family == .accessoryInline {
            Label(snapshot.inlineText, systemImage: "bird")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ForEach(snapshot.items.prefix(3)) { item in
                        HabitRing(
                            fraction: item.card.progress.fraction, status: item.card.progress.status, color: .primary,
                            symbol: item.card.progress.status == .done ? "checkmark" : item.card.symbol, size: 26, lineWidth: 3.5
                        )
                    }
                }
                Text(snapshot.inlineText)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// One habit's ring on the Lock Screen; the user picks the habit.
struct HabitRingWidget: Widget {
    static let kind = "com.smartapps.TinyHabits.habitRing"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectHabitIntent.self, provider: HabitRingProvider()) { entry in
            HabitRingLockView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Habit ring")
        .description("One habit's progress.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct HabitRingLockView: View {
    let entry: NestEntry

    var body: some View {
        let items = entry.snapshot.items
        if !entry.isPro {
            Image(systemName: "bird").accessibilityLabel("Fledge Pro")
        } else if let item = items.first(where: { $0.id == entry.selectedHabitID }) ?? items.first {
            ZStack {
                AccessoryWidgetBackground()
                HabitRing(
                    fraction: item.card.progress.fraction, status: item.card.progress.status, color: .primary,
                    symbol: item.card.progress.status == .done ? "checkmark" : item.card.symbol, size: 46, lineWidth: 5
                )
            }
            .accessibilityLabel("\(item.card.name), \(item.card.valueText)")
        } else {
            Image(systemName: "bird")
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    NestWidget()
} timeline: {
    NestEntry(date: .now, snapshot: NestTimeline.sample)
}

#Preview("Medium", as: .systemMedium) {
    NestWidget()
} timeline: {
    NestEntry(date: .now, snapshot: NestTimeline.sample)
}
