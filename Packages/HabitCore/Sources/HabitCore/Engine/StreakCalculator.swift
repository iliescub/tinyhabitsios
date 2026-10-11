import Foundation

public struct Streak: Equatable, Sendable {
    public enum Unit: Sendable { case days, weeks }

    public let current: Int
    public let best: Int
    public let unit: Unit
}

/// Streak rules:
/// - Daily cadence: consecutive days that are done or skipped (a skip keeps the chain but doesn't add to it).
///   Today still pending does not break the streak.
/// - Weekly cadence (N < 7): consecutive weeks with at least N done days. The current week counts only once met.
public enum StreakCalculator {
    public static func streak(
        snapshots: [DaySnapshot],
        cadence: Cadence,
        today: DayKey,
        startedOn: DayKey,
        calendar: Calendar = .current
    ) -> Streak {
        let byDay = Dictionary(snapshots.map { ($0.day, $0.status) }, uniquingKeysWith: { _, last in last })
        return cadence.isDaily
            ? daily(byDay: byDay, today: today, startedOn: startedOn, calendar: calendar)
            : weekly(byDay: byDay, perWeek: cadence.perWeek, today: today, startedOn: startedOn, calendar: calendar)
    }

    private static func daily(byDay: [DayKey: EntryStatus], today: DayKey, startedOn: DayKey, calendar: Calendar) -> Streak {
        var best = 0
        var run = 0
        var day = startedOn
        while day <= today {
            switch byDay[day] ?? .pending {
            case .done:
                run += 1
            case .skipped:
                break
            case .pending:
                if day != today { run = 0 }
            }
            best = max(best, run)
            day = day.adding(days: 1, calendar: calendar)
        }
        return Streak(current: run, best: best, unit: .days)
    }

    private static func weekly(byDay: [DayKey: EntryStatus], perWeek: Int, today: DayKey, startedOn: DayKey, calendar: Calendar) -> Streak {
        guard let firstWeek = calendar.dateInterval(of: .weekOfYear, for: startedOn.date(in: calendar))?.start,
              let currentWeek = calendar.dateInterval(of: .weekOfYear, for: today.date(in: calendar))?.start else {
            return Streak(current: 0, best: 0, unit: .weeks)
        }

        var best = 0
        var run = 0
        var weekStart = firstWeek
        while weekStart <= currentWeek {
            let doneCount = (0..<7).reduce(0) { count, offset in
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return count }
                let key = DayKey(date, calendar: calendar, dayEndHour: 0)
                return byDay[key] == .done ? count + 1 : count
            }
            let isCurrent = weekStart == currentWeek
            if doneCount >= perWeek {
                run += 1
            } else if !isCurrent {
                run = 0
            }
            best = max(best, run)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = next
        }
        return Streak(current: run, best: best, unit: .weeks)
    }
}
