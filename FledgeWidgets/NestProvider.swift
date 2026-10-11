import Foundation
import SwiftData
import WidgetKit
import HabitCore
import FledgeUI

struct NestEntry: TimelineEntry {
    let date: Date
    let snapshot: NestSnapshot
    /// For the configurable Lock Screen ring.
    var selectedHabitID: UUID?
}

enum NestTimeline {
    /// Reads the shared store. Widgets show stored values; Health is synced by the app (docs/SPEC.md).
    static func snapshot(now: Date = .now) -> NestSnapshot {
        guard let container = try? SharedStore.makeContainer() else { return .placeholder }
        return NestSnapshot(context: ModelContext(container), day: DayKey.today(now: now))
    }

    /// Refresh every 15 minutes and right after the day ends.
    static func nextRefresh(after now: Date) -> Date {
        let soon = now.addingTimeInterval(15 * 60)
        let today = DayKey.today(now: now)
        let dayEnd = HealthAggregation.dayInterval(today, dayEndHour: FledgeSettings.dayEndHour).end
        return min(soon, dayEnd.addingTimeInterval(1))
    }

    static var sample: NestSnapshot {
        let day = DayKey.today()
        func item(_ name: String, _ symbol: String, _ color: String, _ source: HabitSourceID, _ target: Double, _ unit: String, _ value: Double, _ status: EntryStatus) -> NestSnapshot.Item {
            NestSnapshot.Item(
                id: UUID(),
                card: HabitCardModel(
                    name: name, symbol: symbol, colorKey: color, source: source, target: target, unit: unit,
                    cadence: .daily, startedOn: day.adding(days: -20), today: day, todayValue: value,
                    todayStatus: status, todayCompletedBy: status == .done ? .manual : nil, history: []
                ),
                lastUpdated: source.isAuto ? .now : nil
            )
        }
        return NestSnapshot(day: day, items: [
            item("Walk", "figure.walk", "dawn", .steps, 6_000, "steps", 4_200, .pending),
            item("Read", "book.fill", "sky", .manual, 1, "times", 0, .done),
            item("Meditate", "brain.head.profile", "meadow", .mindfulMinutes, 5, "min", 2, .pending),
        ])
    }
}

struct NestProvider: TimelineProvider {
    func placeholder(in context: Context) -> NestEntry {
        NestEntry(date: .now, snapshot: NestTimeline.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (NestEntry) -> Void) {
        let snapshot = context.isPreview ? NestTimeline.sample : NestTimeline.snapshot()
        completion(NestEntry(date: .now, snapshot: snapshot.items.isEmpty && context.isPreview ? NestTimeline.sample : snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NestEntry>) -> Void) {
        let now = Date.now
        let entry = NestEntry(date: now, snapshot: NestTimeline.snapshot(now: now))
        completion(Timeline(entries: [entry], policy: .after(NestTimeline.nextRefresh(after: now))))
    }
}

struct HabitRingProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NestEntry {
        NestEntry(date: .now, snapshot: NestTimeline.sample)
    }

    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> NestEntry {
        NestEntry(date: .now, snapshot: context.isPreview ? NestTimeline.sample : NestTimeline.snapshot(), selectedHabitID: configuration.habit?.id)
    }

    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<NestEntry> {
        let now = Date.now
        let entry = NestEntry(date: now, snapshot: NestTimeline.snapshot(now: now), selectedHabitID: configuration.habit?.id)
        return Timeline(entries: [entry], policy: .after(NestTimeline.nextRefresh(after: now)))
    }
}
