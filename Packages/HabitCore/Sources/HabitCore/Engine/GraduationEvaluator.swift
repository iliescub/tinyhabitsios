import Foundation

public struct GraduationRule: Codable, Hashable, Sendable {
    /// Minimum days since the habit started.
    public var minDays: Int
    /// Required completion rate over the trailing window (0...1).
    public var threshold: Double
    /// Trailing window length in days.
    public var windowDays: Int
    /// Days shown as the suggested target ("66 days to automaticity", Lally et al. 2010).
    public var suggestedDays: Int

    public init(minDays: Int = 30, threshold: Double = 0.8, windowDays: Int = 30, suggestedDays: Int = 66) {
        self.minDays = minDays
        self.threshold = threshold
        self.windowDays = windowDays
        self.suggestedDays = suggestedDays
    }

    public static let standard = GraduationRule()
}

public struct GraduationStatus: Equatable, Sendable {
    public let daysActive: Int
    /// Completion rate over the trailing window, 0...1.
    public let recentRate: Double
    public let isReady: Bool
    /// Days left until the suggested graduation day (never negative).
    public let daysToSuggested: Int
}

public enum GraduationEvaluator {
    /// Ready when active for at least `minDays` AND the trailing-window rate meets `threshold`.
    /// Skipped days are excluded from the expected count, so rest days don't count against the habit.
    public static func status(
        snapshots: [DaySnapshot],
        cadence: Cadence,
        startedOn: DayKey,
        today: DayKey,
        rule: GraduationRule = .standard,
        calendar: Calendar = .current
    ) -> GraduationStatus {
        let daysActive = max(0, startedOn.days(to: today, calendar: calendar)) + 1
        let windowStart = max(startedOn, today.adding(days: -(rule.windowDays - 1), calendar: calendar))
        let windowLength = windowStart.days(to: today, calendar: calendar) + 1

        let inWindow = snapshots.filter { $0.day >= windowStart && $0.day <= today }
        let done = inWindow.filter { $0.status == .done }.count
        let skipped = inWindow.filter { $0.status == .skipped }.count

        let expectedPerDay = Double(cadence.perWeek) / 7
        let expected = max(1, Double(windowLength - skipped) * expectedPerDay)
        let rate = min(1, Double(done) / expected)

        return GraduationStatus(
            daysActive: daysActive,
            recentRate: rate,
            isReady: daysActive >= rule.minDays && rate >= rule.threshold,
            daysToSuggested: max(0, rule.suggestedDays - daysActive)
        )
    }
}
