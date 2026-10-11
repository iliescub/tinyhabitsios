import Foundation

/// How often a habit is expected: every day, or N days per week.
public struct Cadence: Hashable, Sendable {
    public let perWeek: Int

    public init(perWeek: Int) {
        self.perWeek = min(max(perWeek, 1), 7)
    }

    public static let daily = Cadence(perWeek: 7)
    public var isDaily: Bool { perWeek == 7 }
}

/// The value-type view of one day, used by the streak and graduation engines.
public struct DaySnapshot: Hashable, Sendable {
    public let day: DayKey
    public let status: EntryStatus

    public init(day: DayKey, status: EntryStatus) {
        self.day = day
        self.status = status
    }
}

/// Result of evaluating a single day for display (ring fill + status).
public struct DayProgress: Equatable, Sendable {
    public let status: EntryStatus
    public let value: Double
    public let target: Double
    /// 0...1, drives the progress ring.
    public let fraction: Double
}

public enum DayEvaluator {
    /// Combines the stored state with the latest measured value.
    /// - A manual "done" is sticky: Health data never undoes it.
    /// - A "skipped" day stays skipped.
    /// - Otherwise the day is done once `value >= target`.
    public static func evaluate(
        value: Double,
        target: Double,
        stored: EntryStatus,
        completedBy: CompletedBy?
    ) -> DayProgress {
        let safeTarget = max(target, 0.0001)
        let measured = min(max(value, 0) / safeTarget, 1)

        if stored == .skipped {
            return DayProgress(status: .skipped, value: value, target: target, fraction: measured)
        }
        if stored == .done, let completedBy, completedBy != .auto {
            return DayProgress(status: .done, value: value, target: target, fraction: 1)
        }
        let status: EntryStatus = value >= safeTarget ? .done : .pending
        return DayProgress(status: status, value: value, target: target, fraction: status == .done ? 1 : measured)
    }

    /// Amount added by one "+" tap on a manual quantity habit (about a quarter of the target, at least 1).
    public static func increment(for target: Double) -> Double {
        max(1, (target / 4).rounded())
    }
}
