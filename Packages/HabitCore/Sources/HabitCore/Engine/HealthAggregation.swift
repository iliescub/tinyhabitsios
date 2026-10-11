import Foundation

/// Pure helpers that turn Health samples into one daily value. HealthKit itself lives in FledgeHealth.
public enum HealthAggregation {
    /// The real-time span of a `DayKey`: from the day-end hour on that date to the same hour the next day.
    public static func dayInterval(_ day: DayKey, dayEndHour: Int, calendar: Calendar = .current) -> DateInterval {
        let midnight = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? day.date(in: calendar)
        let start = calendar.date(byAdding: .hour, value: dayEndHour, to: midnight) ?? midnight
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    /// The night that belongs to `day`: 18:00 the evening before until 14:00 on the day.
    public static func sleepWindow(for day: DayKey, calendar: Calendar = .current) -> DateInterval {
        let midnight = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? day.date(in: calendar)
        let start = calendar.date(byAdding: .hour, value: -6, to: midnight) ?? midnight
        let end = calendar.date(byAdding: .hour, value: 14, to: midnight) ?? midnight
        return DateInterval(start: start, end: end)
    }

    /// Hours of the longest sleep session ending inside `window`. Asleep intervals closer than `gap`
    /// are merged into one session, so a short wake-up doesn't split the night but a nap stays separate.
    public static func mainSleepHours(asleep intervals: [DateInterval], window: DateInterval, gap: TimeInterval = 20 * 60) -> Double {
        let sorted = intervals.sorted { $0.start < $1.start }
        var sessions: [[DateInterval]] = []
        for interval in sorted {
            if let last = sessions.last?.last, interval.start.timeIntervalSince(last.end) <= gap {
                sessions[sessions.count - 1].append(interval)
            } else {
                sessions.append([interval])
            }
        }
        let inWindow = sessions.filter { session in
            guard let end = session.last?.end else { return false }
            return end > window.start && end <= window.end
        }
        let longest = inWindow.map { $0.reduce(0) { $0 + $1.duration } }.max() ?? 0
        return longest / 3600
    }

    /// Minutes of `intervals` that fall inside `range` (e.g. mindful sessions, workout durations).
    public static func totalMinutes(_ intervals: [DateInterval], within range: DateInterval) -> Double {
        intervals.reduce(0) { total, interval in
            guard let overlap = interval.intersection(with: range) else { return total }
            return total + overlap.duration / 60
        }
    }
}

/// "Not seeing data?" hint for auto habits (docs/SPEC.md, Automatic completion).
public enum NoDataHeuristic {
    /// True when an auto habit shows zero today after 18:00 and had zero on the two previous days,
    /// and has been active for at least three days. Read access denial looks exactly like this.
    public static func shouldHint(todayValue: Double, previousValues: [Double], daysActive: Int, hour: Int) -> Bool {
        guard daysActive >= 3, hour >= 18, todayValue == 0, previousValues.count >= 2 else { return false }
        return previousValues.prefix(2).allSatisfy { $0 == 0 }
    }
}
