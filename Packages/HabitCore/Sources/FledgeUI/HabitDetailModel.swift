import Foundation
import HabitCore

/// 12-week × 7-day grid for the habit detail heatmap (docs/DESIGN.md §6.2). Columns are weeks, oldest first.
public struct HeatmapModel: Equatable, Sendable {
    public enum CellState: Equatable, Sendable {
        case beforeStart, done, rest, missed, pending, future
    }

    public struct Cell: Identifiable, Equatable, Sendable {
        public let day: DayKey
        public let state: CellState
        public let isToday: Bool
        public var id: String { day.rawValue }
    }

    public let weeks: [[Cell]]
    /// Month name over the first column of each month ("Jul", "Aug"…), as (column, text).
    public let monthLabels: [MonthLabel]
    /// One label per row; every other row is empty so the column stays light ("M", "", "W", "", "F", "", "").
    public let weekdayLabels: [String]

    public struct MonthLabel: Equatable, Sendable {
        public let week: Int
        public let text: String
    }

    public init(
        snapshots: [DaySnapshot], startedOn: DayKey, today: DayKey, weekCount: Int = 12,
        calendar: Calendar = .current, locale: Locale = .current
    ) {
        var calendar = calendar
        calendar.locale = locale
        let byDay = Dictionary(snapshots.map { ($0.day, $0.status) }, uniquingKeysWith: { _, last in last })
        let todayDate = today.date(in: calendar)
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: todayDate)?.start ?? todayDate
        let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -(weekCount - 1), to: thisWeekStart) ?? thisWeekStart

        weeks = (0..<weekCount).map { week in
            (0..<7).map { weekday in
                let date = calendar.date(byAdding: .day, value: week * 7 + weekday, to: firstWeekStart) ?? firstWeekStart
                let day = DayKey(date, calendar: calendar, dayEndHour: 0)
                return Cell(day: day, state: Self.state(for: day, byDay: byDay, startedOn: startedOn, today: today), isToday: day == today)
            }
        }

        var labels: [MonthLabel] = []
        var lastMonth: Int?
        for (index, week) in weeks.enumerated() {
            guard let first = week.first else { continue }
            if first.day.month != lastMonth {
                labels.append(MonthLabel(week: index, text: calendar.shortMonthSymbols[first.day.month - 1]))
                lastMonth = first.day.month
            }
        }
        // The first column's month is dropped when the next month starts one column later: the labels would overlap.
        if labels.count > 1, labels[1].week - labels[0].week < 2 { labels.removeFirst() }
        monthLabels = labels

        let symbols = calendar.veryShortWeekdaySymbols
        weekdayLabels = (0..<7).map { row in
            row.isMultiple(of: 2) && row < 6 ? symbols[(calendar.firstWeekday - 1 + row) % 7] : ""
        }
    }

    private static func state(for day: DayKey, byDay: [DayKey: EntryStatus], startedOn: DayKey, today: DayKey) -> CellState {
        if day > today { return .future }
        if day < startedOn { return .beforeStart }
        switch byDay[day] {
        case .done: return .done
        case .skipped: return .rest
        default: return day == today ? .pending : .missed
        }
    }
}

/// Numbers for the habit detail screen: streaks, 30-day rate and the flight track.
public struct HabitDetailStats: Equatable, Sendable {
    public let streak: Streak
    public let graduation: GraduationStatus
    public let rule: GraduationRule
    /// Rest days left this month; nil = unlimited (weekly cadence).
    public let restDaysLeft: Int?

    public init(
        snapshots: [DaySnapshot],
        cadence: Cadence,
        startedOn: DayKey,
        today: DayKey,
        rule: GraduationRule = .standard,
        calendar: Calendar = .current
    ) {
        self.rule = rule
        streak = StreakCalculator.streak(snapshots: snapshots, cadence: cadence, today: today, startedOn: startedOn, calendar: calendar)
        graduation = GraduationEvaluator.status(snapshots: snapshots, cadence: cadence, startedOn: startedOn, today: today, rule: rule, calendar: calendar)
        restDaysLeft = RestDayPolicy.remaining(snapshots: snapshots, cadence: cadence, on: today)
    }

    public var streakText: String {
        let unit = streak.unit == .days ? (streak.current == 1 ? "day" : "days") : (streak.current == 1 ? "week" : "weeks")
        return "\(streak.current) \(unit)"
    }

    public var bestText: String {
        let unit = streak.unit == .days ? (streak.best == 1 ? "day" : "days") : (streak.best == 1 ? "week" : "weeks")
        return "\(streak.best) \(unit)"
    }

    public var rateText: String {
        "\(Int((graduation.recentRate * 100).rounded())) %"
    }

    /// "Day 37 · 86 % of the last 30 days"
    public var flightLine: String {
        "Day \(graduation.daysActive) · \(rateText) of the last \(rule.windowDays) days"
    }

    public var flightFraction: Double {
        min(1, Double(graduation.daysActive) / Double(max(rule.suggestedDays, 1)))
    }

    public var tickFraction: Double {
        Double(rule.minDays) / Double(max(rule.suggestedDays, 1))
    }
}

extension FledgeTheme {
    /// Symbols offered in the habit editor.
    public static let habitSymbols = [
        "figure.walk", "flame.fill", "dumbbell.fill", "figure.stand", "brain.head.profile", "bed.double.fill",
        "drop.fill", "sun.max.fill", "book.fill", "figure.cooldown", "pencil", "leaf.fill",
        "fork.knife", "pills.fill", "music.note", "paintbrush.fill", "phone.down.fill", "heart.fill",
        "bicycle", "figure.pool.swim", "cup.and.saucer.fill", "moon.stars.fill", "graduationcap.fill", "star.fill",
    ]

    /// Units offered for manual habits.
    public static let manualUnits = ["times", "min", "pages", "glasses", "km"]
}
