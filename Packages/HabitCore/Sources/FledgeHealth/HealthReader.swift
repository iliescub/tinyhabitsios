import Foundation
import HealthKit
import HabitCore

/// Reads one daily value per metric. Read-only: Fledge never writes to Health.
/// HKHealthStore is documented as thread-safe, hence `@unchecked Sendable`.
public final class HealthReader: @unchecked Sendable {
    public static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    let store = HKHealthStore()

    public init() {}

    /// Shows the system sheet the first time; later calls return immediately.
    /// Note: HealthKit never reveals whether *read* access was denied (denial looks like no data).
    public func requestAuthorization(for metrics: [HealthMetric]) async throws {
        guard Self.isAvailable, !metrics.isEmpty else { return }
        try await store.requestAuthorization(toShare: [], read: Set(metrics.map(\.sampleType)))
    }

    /// The value for `day` in the habit's unit (steps, minutes, litres, hours, workouts…).
    public func value(for metric: HealthMetric, on day: DayKey, dayEndHour: Int, calendar: Calendar = .current) async throws -> Double {
        let range = HealthAggregation.dayInterval(day, dayEndHour: dayEndHour, calendar: calendar)
        switch metric {
        case .quantity(let identifier, let unit):
            return try await sum(HKQuantityType(identifier), unit: HKUnit(from: unit), in: range)

        case .mindfulMinutes:
            let samples = try await categorySamples(HKCategoryType(.mindfulSession), in: range)
            return HealthAggregation.totalMinutes(samples.map { DateInterval(start: $0.startDate, end: $0.endDate) }, within: range)

        case .standHours:
            let samples = try await categorySamples(HKCategoryType(.appleStandHour), in: range)
            return Double(samples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count)

        case .sleepHours:
            let window = HealthAggregation.sleepWindow(for: day, calendar: calendar)
            let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
            let samples = try await categorySamples(HKCategoryType(.sleepAnalysis), in: window)
            let intervals = samples
                .filter { asleep.contains($0.value) }
                .map { DateInterval(start: $0.startDate, end: $0.endDate) }
            return HealthAggregation.mainSleepHours(asleep: intervals, window: window)

        case .workouts(let activity, let minutes):
            let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: .strictStartDate)
            let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [])
            let workouts = try await descriptor.result(for: store).filter { activity == nil || $0.workoutActivityType == activity }
            return minutes ? workouts.reduce(0) { $0 + $1.duration / 60 } : Double(workouts.count)
        }
    }

    /// True when Health has any sample of this metric in the last `days` days (used to offer manual tracking).
    public func hasRecentSamples(for metric: HealthMetric, days: Int = 7, now: Date = .now) async -> Bool {
        let start = now.addingTimeInterval(-Double(days) * 86_400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [HKSamplePredicate<HKSample>.sample(type: metric.sampleType, predicate: predicate)],
            sortDescriptors: [],
            limit: 1
        )
        return ((try? await descriptor.result(for: store))?.isEmpty == false)
    }

    // MARK: - Queries

    private func sum(_ type: HKQuantityType, unit: HKUnit, in range: DateInterval) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: type, predicate: predicate), options: .cumulativeSum)
        return try await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    private func categorySamples(_ type: HKCategoryType, in range: DateInterval) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end)
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: predicate)], sortDescriptors: [])
        return try await descriptor.result(for: store)
    }
}
