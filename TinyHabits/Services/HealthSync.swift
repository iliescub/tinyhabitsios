import Foundation
import SwiftData
import WidgetKit
import HabitCore
import FledgeHealth

/// Keeps Health-sourced habits up to date (HK-3): on launch, when the app becomes active, and when
/// HealthKit background delivery wakes the app. Writes go through the HabitCore write API on the main context,
/// so SwiftUI's @Query sees them immediately.
@MainActor
final class HealthSync {
    /// Set at launch by `FledgeApp`.
    static private(set) var shared: HealthSync?

    private var container: ModelContainer
    private let reader = HealthReader()
    private lazy var observer = HealthObserver(reader: reader)
    private var observedMetrics: Set<HealthMetric> = []
    private var isRefreshing = false

    static func start(container: ModelContainer) {
        let sync = HealthSync(container: container)
        shared = sync
        sync.updateObservers()
    }

    private init(container: ModelContainer) {
        self.container = container
    }

    /// Called when the app reopened its store after another process wrote to it.
    func use(container: ModelContainer) {
        self.container = container
        Task { await refresh() }
    }

    /// Asks for read access for one source (system sheet only the first time) and reports whether
    /// Health has any recent data for it. Used before adding a "Done for you" habit (HK-4).
    func prepare(source: HabitSourceID, unit: String) async -> (metric: HealthMetric?, hasRecentData: Bool) {
        guard HealthReader.isAvailable, let metric = HealthMetric(source: source, unit: unit) else { return (nil, false) }
        do {
            try await reader.requestAuthorization(for: [metric])
        } catch {
            return (metric, false)
        }
        return (metric, await reader.hasRecentSamples(for: metric))
    }

    /// HEAD-1: one value per day for the 30 days before today, oldest first, for the head start in setup.
    /// Nil when Health isn't available or this source has no Health metric. Call after `prepare` (read access).
    func baselineValues(source: HabitSourceID, unit: String) async -> [Double]? {
        guard HealthReader.isAvailable, let metric = HealthMetric(source: source, unit: unit) else { return nil }
        let dayEndHour = FledgeSettings.dayEndHour
        let today = DayKey.today()
        var values: [Double] = []
        for offset in (1...HealthBaseline.days).reversed() {
            let day = today.adding(days: -offset)
            values.append((try? await reader.value(for: metric, on: day, dayEndHour: dayEndHour)) ?? 0)
        }
        return values
    }

    /// HEAD-1: records the 30 days before a new Health habit started, so its history isn't empty on day one.
    /// Streaks and graduation count from the start date only (StreakCalculator, GraduationEvaluator), and the
    /// heatmap shows these days as "Before Fledge".
    func backfill(habitID: UUID, source: HabitSourceID, unit: String) async {
        guard let values = await baselineValues(source: source, unit: unit) else { return }
        let context = container.mainContext
        let today = DayKey.today()
        for (index, value) in values.enumerated() where value > 0 {
            let day = today.adding(days: index - values.count)
            try? context.record(value: value, habitID: habitID, on: day, by: .auto)
        }
    }

    /// Re-registers observers when the set of Health habits changes, then refreshes.
    func updateObservers() {
        let metrics = Set(trackedHabits().compactMap { HealthMetric(source: $0.source, unit: $0.unit) })
        if metrics != observedMetrics {
            observedMetrics = metrics
            if metrics.isEmpty {
                observer.stop()
            } else {
                let reader = reader
                let observer = observer
                Task { [weak self] in
                    try? await reader.requestAuthorization(for: Array(metrics))
                    observer.start(metrics: Array(metrics)) { [weak self] in
                        await self?.refresh()
                    }
                }
            }
        }
        Task { await refresh() }
    }

    /// Reads today's and yesterday's values (late Watch syncs, last night's sleep) and records them.
    func refresh() async {
        guard HealthReader.isAvailable, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let context = container.mainContext
        let dayEndHour = FledgeSettings.dayEndHour
        let today = DayKey.today()
        for habit in trackedHabits() {
            guard let metric = HealthMetric(source: habit.source, unit: habit.unit) else { continue }
            let startedOn = DayKey(habit.startedAt, dayEndHour: dayEndHour)
            for day in [today.adding(days: -1), today] where day >= startedOn {
                guard let value = try? await reader.value(for: metric, on: day, dayEndHour: dayEndHour) else { continue }
                try? context.record(value: value, habitID: habit.id, on: day, by: .auto)
            }
        }
        await Reminders.reconcile(context: context)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func trackedHabits() -> [AutoHabitRef] {
        (try? container.mainContext.trackedAutoHabits()) ?? []
    }
}
