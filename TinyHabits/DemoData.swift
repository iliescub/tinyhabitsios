#if DEBUG
import Foundation
import SwiftData
import SwiftUI
import HabitCore
import FledgeUI

/// Launch with `-FledgeDemoData` to run on an in-memory store with sample habits (never touches real data).
enum DemoData {
    static let launchArgument = "-FledgeDemoData"

    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    /// `-FledgeDemoScreen detail|graduation|add|configure|flown|settings|paywall|onboarding[-pick|-health|-reminders]`
    /// opens that screen on launch (for screenshots).
    static var screen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-FledgeDemoScreen"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// `-FledgeDemoToday yyyy-MM-dd` pins the demo's "now" (App Store screenshots show a resolution in progress in 2027).
    static var now: Date {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-FledgeDemoToday"), arguments.indices.contains(index + 1),
              let day = DayKey(rawValue: arguments[index + 1]) else { return .now }
        return Calendar.fledge.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 10)) ?? .now
    }

    static func makeContainer() throws -> ModelContainer {
        let container = try SharedStore.makeContainer(inMemory: true)
        try seed(ModelContext(container))
        return container
    }

    private static func seed(_ context: ModelContext) throws {
        let now = DemoData.now
        let today = DayKey(now)
        let calendar = Calendar.fledge
        // `-FledgeDemoScreen freshstart`: a quiet last week (RES-5); `firstweek`: a resolution started 2 days ago (UXR-2).
        let quietWeek = screen == "freshstart"
        // `kept`: every habit of the resolution has flown (RES-7); `newresolution`: habits but no resolution yet.
        let keptDemo = screen == "kept"
        let noResolution = screen == "newresolution"
        let firstWeek = screen == "firstweek"

        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now) ?? now }
        func add(_ name: String, _ symbol: String, _ color: String, _ source: HabitSourceID, _ target: Double, _ unit: String,
                 cue: String = "", startedDaysAgo: Int) throws -> Habit {
            try context.addHabit(
                draft: HabitDraft(name: name, symbol: symbol, colorKey: color, source: source, target: target, unit: unit, cue: cue),
                startedAt: daysAgo(startedDaysAgo)
            )
        }

        // A Health graduate from before the resolution, for the Flown shelf's holding trend ("Other habits").
        let water = try add("Drink water", "drop.fill", "teal", .water, 2, "L", startedDaysAgo: 75)
        try context.graduate(habitID: water.id, on: daysAgo(20))
        for offset in 1...20 where offset % 6 != 0 && offset != 2 {
            try context.setDone(true, habitID: water.id, on: today.adding(days: -offset), by: .auto)
        }

        // RES-7: the resolution, with "why" and a letter. Habits added while it's active serve it (write API),
        // so they're added after it; `newresolution` leaves it out.
        if !noResolution {
            try context.startResolution(
                ResolutionDraft(
                    text: "Feel calmer", templateID: "calmer-mind", why: "So evenings feel like mine again",
                    letter: "Dear December me, I hope the walks stuck."
                ),
                startDay: today.adding(days: firstWeek ? -2 : -39)
            )
        }

        // Walk: auto, 40 days in, strong history → ready to fly; partly done today.
        let walk = try add("Walk", "figure.walk", "dawn", .steps, 6_000, "steps", cue: "After lunch", startedDaysAgo: 39)
        for offset in 1...39 where offset % 9 != 0 && !(quietWeek && offset <= 7) {
            try context.setDone(true, habitID: walk.id, on: today.adding(days: -offset), by: .auto)
        }
        try context.record(value: 4_210, habitID: walk.id, on: today, by: .auto)

        // Stretch: flew two weeks ago (Walk is still in the nest, so the resolution isn't kept).
        let stretch = try add("Stretch", "figure.cooldown", "lilac", .manual, 1, "times", cue: "After I brush my teeth", startedDaysAgo: 80)
        try context.graduate(habitID: stretch.id, on: daysAgo(14))

        // Read: manual, 12 days in, done today.
        let read = try add("Read", "book.fill", "sky", .manual, 1, "times", cue: "When I get into bed", startedDaysAgo: 11)
        try context.setDone(true, habitID: read.id, on: today, by: .manual)

        // Meditate: auto, 3 days in, rest day today.
        let meditate = try add("Meditate", "brain.head.profile", "meadow", .mindfulMinutes, 5, "min", cue: "After my morning coffee", startedDaysAgo: 2)
        try context.skip(habitID: meditate.id, on: today)
        // HEAD-1 backfill: the Health days before Meditate started ("Before Yearling" on its heatmap).
        for offset in 3...30 where offset % 4 != 0 {
            try context.record(value: 6, habitID: meditate.id, on: today.adding(days: -offset), by: .auto)
        }

        if keptDemo {
            for habit in [walk, read, meditate] { try context.graduate(habitID: habit.id, on: now) }
        }
    }
}
extension DemoData {
    /// Sample "last 30 days" for the head start (HEAD-1) in screenshots: Move is already a habit, Sleep is within reach,
    /// everything else starts smaller. Deterministic, so screenshots don't change between runs.
    static func baselineValues(for source: HabitSourceID) -> [Double] {
        (0..<30).map { day in
            let wobble = Double((day * 37) % 11) / 10        // 0.0 … 1.0
            switch source {
            case .exerciseMinutes: return day % 9 == 4 ? 12 : 22 + wobble * 14
            case .sleep: return 6.4 + wobble * 1.1
            case .steps: return day % 7 == 6 ? 0 : 3_800 + wobble * 2_600
            default: return day % 3 == 0 ? 0 : 3 + wobble * 4
            }
        }
    }
}

/// `-FledgeDemoScreen widgets`: every Home Screen widget size with the demo nest, at iPhone widget sizes
/// (for review and the App Store "widgets" screenshot; the simulator can't screenshot real widgets from the CLI).
struct WidgetGallery: View {
    let snapshot: NestSnapshot

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 22) {
                    tile(.small, width: 170, height: 170)
                    lockScreen
                }
                tile(.medium, width: 362, height: 170)
                tile(.large, width: 362, height: 382)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // iPad-only extra large (13" size).
                    tile(.extraLarge, width: 715, height: 342)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(colors: [Color(red: 0.36, green: 0.55, blue: 0.95), Color(red: 0.98, green: 0.72, blue: 0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    /// A Lock Screen with the rectangular nest widget: three mini rings and the one-line summary.
    private var lockScreen: some View {
        VStack(spacing: 6) {
            Text(snapshot.day.date().formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                .font(.system(size: 11, weight: .semibold))
            Text("9:41")
                .font(.system(size: 52, weight: .semibold, design: .rounded))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    ForEach(snapshot.items.prefix(3)) { item in
                        HabitRing(
                            fraction: item.card.progress.fraction, status: item.card.progress.status,
                            color: .white, symbol: item.card.symbol, size: 24, lineWidth: 3
                        )
                    }
                }
                Text(snapshot.inlineText)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.18), in: .rect(cornerRadius: 12, style: .continuous))
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: 170, height: 170)
        .background(
            LinearGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.36), Color(red: 0.3, green: 0.36, blue: 0.7)], startPoint: .top, endPoint: .bottom)
        )
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }

    private func tile(_ family: NestWidgetContent<HabitRing>.Family, width: CGFloat, height: CGFloat, pro: Bool = true, empty: Bool = false) -> some View {
        NestWidgetContent(
            family: family,
            snapshot: empty ? NestSnapshot(day: snapshot.day, items: []) : snapshot,
            date: .now,
            isPro: pro
        ) { item, size, lineWidth in
            HabitRing(
                fraction: item.card.progress.fraction, status: item.card.progress.status,
                color: FledgeTheme.habitColor(item.card.colorKey), symbol: item.card.symbol, size: size, lineWidth: lineWidth
            )
        }
        .padding(16)
        .frame(width: width, height: height, alignment: family == .small ? .center : .topLeading)
        .background(NestWidgetBackground())
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}
#endif
