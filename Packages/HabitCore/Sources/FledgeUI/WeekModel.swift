import Foundation
import HabitCore

/// The Today week strip (UX-5): the last seven days, today on the right, one dot per habit.
/// A missed day is an empty dot, never a red one ("progress, not perfection").
public struct WeekModel: Equatable, Sendable {
    public struct Habit: Sendable {
        public let colorKey: String
        public let startedOn: DayKey
        public let snapshots: [DaySnapshot]

        public init(colorKey: String, startedOn: DayKey, snapshots: [DaySnapshot]) {
            self.colorKey = colorKey
            self.startedOn = startedOn
            self.snapshots = snapshots
        }
    }

    public enum DotState: Equatable, Sendable {
        /// Met that day.
        case done
        /// Rest day.
        case rest
        /// Not done (or today, not done yet).
        case open
        /// Before the habit started: no dot.
        case none
    }

    public struct Dot: Equatable, Sendable {
        public let colorKey: String
        public let state: DotState
    }

    public struct Day: Identifiable, Equatable, Sendable {
        public let day: DayKey
        /// One letter: "M", "T"…
        public let label: String
        public let isToday: Bool
        public let dots: [Dot]
        /// "Tuesday: 2 of 3 done, 1 rest day"
        public let accessibilityLabel: String
        public var id: String { day.rawValue }
    }

    public let days: [Day]

    public init(habits: [Habit], today: DayKey, calendar: Calendar = .current, locale: Locale = .current) {
        var calendar = calendar
        calendar.locale = locale
        let lookup = habits.map { habit in
            Dictionary(habit.snapshots.map { ($0.day, $0.status) }, uniquingKeysWith: { _, last in last })
        }

        days = (0..<7).map { index in
            let day = today.adding(days: index - 6, calendar: calendar)
            let weekday = calendar.component(.weekday, from: day.date(in: calendar)) - 1
            let dots = habits.enumerated().map { offset, habit in
                let state: DotState
                if day < habit.startedOn {
                    state = .none
                } else {
                    switch lookup[offset][day] {
                    case .done: state = .done
                    case .skipped: state = .rest
                    default: state = .open
                    }
                }
                return Dot(colorKey: habit.colorKey, state: state)
            }
            let tracked = dots.filter { $0.state != .none }
            let done = tracked.filter { $0.state == .done }.count
            let rest = tracked.filter { $0.state == .rest }.count
            var spoken = "\(day == today ? "Today" : calendar.weekdaySymbols[weekday]): "
            spoken += tracked.isEmpty ? "nothing tracked" : "\(done) of \(tracked.count) done"
            if rest > 0 { spoken += rest == 1 ? ", 1 rest day" : ", \(rest) rest days" }
            return Day(
                day: day,
                label: calendar.veryShortWeekdaySymbols[weekday],
                isToday: day == today,
                dots: dots,
                accessibilityLabel: spoken
            )
        }
    }
}

/// "Journey to fly" on the habit detail (UX-7): day 1 → day 30 (can fly) → day 66 (automatic).
public struct JourneyModel: Equatable, Sendable {
    public struct Milestone: Equatable, Sendable {
        /// 0…1 along the track.
        public let fraction: Double
        public let title: String
        public let subtitle: String
        public let isReached: Bool
        /// The day the habit may graduate (gold).
        public let isGate: Bool
    }

    public let milestones: [Milestone]
    /// 0…1, where the bird sits.
    public let progress: Double
    /// "Day 40 · 87% of the last 30 days"
    public let headline: String
    /// "Ready whenever you are.", "18 days until it can fly.", "Needs 80% of the last 30 days to fly."
    public let status: String

    public init(stats: HabitDetailStats, startedOn: DayKey, locale: Locale = .current, calendar: Calendar = .current) {
        let rule = stats.rule
        let days = stats.graduation.daysActive
        let suggested = Double(max(rule.suggestedDays, 1))
        progress = min(1, Double(days) / suggested)
        let rate = Int((stats.graduation.recentRate * 100).rounded())
        headline = "Day \(days) · \(rate)% of the last \(rule.windowDays) days"

        if stats.graduation.isReady {
            status = "Ready whenever you are."
        } else if days < rule.minDays {
            let left = rule.minDays - days
            status = left == 1 ? "1 day until it can fly." : "\(left) days until it can fly."
        } else {
            status = "Needs \(Int((rule.threshold * 100).rounded()))% of the last \(rule.windowDays) days to fly."
        }

        let started = startedOn.date(in: calendar).formatted(.dateTime.day().month(.abbreviated).locale(locale))
        milestones = [
            Milestone(fraction: 0, title: "Day 1", subtitle: started, isReached: true, isGate: false),
            Milestone(
                fraction: Double(rule.minDays) / suggested, title: "Day \(rule.minDays)", subtitle: "can fly",
                isReached: days >= rule.minDays, isGate: true
            ),
            Milestone(fraction: 1, title: "Day \(rule.suggestedDays)", subtitle: "automatic", isReached: days >= rule.suggestedDays, isGate: false),
        ]
    }
}

/// The Flown shelf preview at the bottom of Today (UX-5).
public enum FlownPreview {
    /// "Stretch flew on 30 Sep after 67 days." / "Walk and 2 more have flown." / first-flight hint.
    public static func text(latestName: String?, flewOn: Date?, days: Int?, total: Int, rule: GraduationRule = .standard, locale: Locale = .current) -> String {
        guard total > 0, let latestName else {
            return "Habits that stick can fly from day \(rule.minDays)."
        }
        if total > 1 {
            return total == 2 ? "\(latestName) and 1 more have flown." : "\(latestName) and \(total - 1) more have flown."
        }
        guard let flewOn, let days else { return "\(latestName) has flown." }
        return "\(latestName) flew on \(flewOn.formatted(.dateTime.day().month(.abbreviated).locale(locale))) after \(days) days."
    }
}
