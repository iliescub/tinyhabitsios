import Foundation
import HabitCore

/// Everything a habit card (or widget row) shows, computed from model values only, so it is unit-testable.
public struct HabitCardModel: Equatable, Sendable {
    public let name: String
    public let symbol: String
    public let colorKey: String
    public let isAuto: Bool
    public let target: Double
    public let unit: String
    public let progress: DayProgress
    /// e.g. "4,210 / 6,000 steps", "Done", "Rest day".
    public let valueText: String
    /// e.g. "23 days to fly", "Ready to fly".
    public let flightText: String
    /// 0...1 position on the day-0 → suggested-day track.
    public let flightFraction: Double
    public let isReadyToFly: Bool

    public init(
        name: String,
        symbol: String,
        colorKey: String,
        source: HabitSourceID,
        target: Double,
        unit: String,
        cadence: Cadence,
        startedOn: DayKey,
        today: DayKey,
        todayValue: Double,
        todayStatus: EntryStatus,
        todayCompletedBy: CompletedBy?,
        history: [DaySnapshot],
        rule: GraduationRule = .standard,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) {
        self.name = name
        self.symbol = symbol
        self.colorKey = colorKey
        self.isAuto = source.isAuto
        self.target = target
        self.unit = unit
        let progress = DayEvaluator.evaluate(value: todayValue, target: target, stored: todayStatus, completedBy: todayCompletedBy)
        self.progress = progress
        self.valueText = Self.valueText(progress: progress, target: target, unit: unit, locale: locale)

        let graduation = GraduationEvaluator.status(
            snapshots: history, cadence: cadence, startedOn: startedOn, today: today, rule: rule, calendar: calendar
        )
        self.isReadyToFly = graduation.isReady
        self.flightFraction = min(1, Double(graduation.daysActive) / Double(max(rule.suggestedDays, 1)))
        if graduation.isReady {
            self.flightText = "Ready to fly"
        } else if graduation.daysActive < rule.minDays {
            let left = rule.minDays - graduation.daysActive
            self.flightText = left == 1 ? "1 day until it can fly" : "\(left) days until it can fly"
        } else {
            self.flightText = "\(Int((graduation.recentRate * 100).rounded())) % of the last \(rule.windowDays) days"
        }
    }

    /// Manual habits with an amount (e.g. 10 min) can log partial progress.
    public var isManualQuantity: Bool { !isAuto && target > 1 }

    /// One "+" step for manual quantity habits, e.g. "+3 min".
    public var incrementText: String {
        let step = DayEvaluator.increment(for: target)
        return "+\(step.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }

    static func valueText(progress: DayProgress, target: Double, unit: String, locale: Locale) -> String {
        switch progress.status {
        case .skipped:
            return "Rest day"
        case .done where target <= 1:
            return "Done"
        case .pending where target <= 1:
            return "Not yet"
        default:
            let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1)).locale(locale)
            return "\(progress.value.formatted(style)) / \(target.formatted(style)) \(unit)"
        }
    }
}

/// The one-line summary under the date on Today (docs/DESIGN.md §6.1).
public enum TodaySummary {
    public static func text(for cards: [HabitCardModel]) -> String {
        guard !cards.isEmpty else { return "Your nest is empty. Add up to three habits." }
        let done = cards.filter { $0.progress.status == .done }.count
        let resting = cards.filter { $0.progress.status == .skipped }
        if done == cards.count { return cards.count == 1 ? "Done for today. Nest is quiet." : "All \(cards.count) done. Nest is quiet." }
        if done == 0 && resting.isEmpty { return cards.count == 1 ? "One habit in the nest." : "\(spelled(cards.count)) in the nest." }
        if done + resting.count == cards.count, let rest = resting.first { return "Rest day for \(rest.name)." }
        return "\(done) of \(cards.count) done."
    }

    private static func spelled(_ n: Int) -> String {
        switch n {
        case 2: "Two"
        case 3: "Three"
        default: "\(n)"
        }
    }
}
