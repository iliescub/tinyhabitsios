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
                .containerBackground(for: .widget) { NestWidgetBackground() }
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
        NestWidgetContent(family: contentFamily, snapshot: entry.snapshot, date: entry.date, isPro: entry.isPro) { item, size, lineWidth in
            RingButton(item: item, size: size, lineWidth: lineWidth)
        }
    }

    private var contentFamily: NestWidgetContent<RingButton>.Family {
        switch family {
        case .systemSmall: .small
        case .systemLarge: .large
        default: .medium
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
            symbol: item.card.symbol,
            size: size,
            lineWidth: lineWidth
        )
        if item.card.isAuto {
            ring
                .accessibilityElement()
                .accessibilityLabel(Text("\(item.card.name), \(item.card.valueText), from Apple Health"))
        } else {
            Button(intent: ToggleHabitIntent(habit: HabitEntity(id: item.id, name: item.card.name, symbol: item.card.symbol))) {
                ring
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(item.card.name), \(item.card.valueText)"))
            .accessibilityHint(Text(item.card.progress.status == .done ? "Marks it not done" : "Marks it done"))
        }
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
            Label { Text("Fledge Pro") } icon: { Image.fledgeGlyph(height: 14) }
        } else if family == .accessoryInline {
            Label { Text(snapshot.inlineText) } icon: { Image.fledgeGlyph(height: 14) }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ForEach(snapshot.items.prefix(3)) { item in
                        HabitRing(
                            fraction: item.card.progress.fraction, status: item.card.progress.status, color: .primary,
                            symbol: item.card.symbol, size: 26, lineWidth: 3.5
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
            Image.fledgeGlyph(height: 24).accessibilityLabel("Fledge Pro")
        } else if let item = items.first(where: { $0.id == entry.selectedHabitID }) ?? items.first {
            ZStack {
                AccessoryWidgetBackground()
                HabitRing(
                    fraction: item.card.progress.fraction, status: item.card.progress.status, color: .primary,
                    symbol: item.card.symbol, size: 46, lineWidth: 5
                )
            }
            .accessibilityLabel("\(item.card.name), \(item.card.valueText)")
        } else {
            Image.fledgeGlyph(height: 24)
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
