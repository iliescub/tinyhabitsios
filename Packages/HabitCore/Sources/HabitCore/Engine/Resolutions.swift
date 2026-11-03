import Foundation

// The resolution layer (spec › "Update 2026-11-01", RES-1…RES-8): the year a resolution belongs to, fresh starts
// after a lapse, the approach reframe, the year map and the Kept check. Pure, so it's tested without SwiftData.

/// Dates of a resolution year.
public enum ResolutionYear {
    /// Resolutions started from this month on count for the next year: a November start is a head start on
    /// "my 2027 resolution", the days before Jan 1 show as the run-up.
    public static let nextYearFromMonth = 11

    public static func year(startingOn day: DayKey) -> Int {
        day.month >= nextYearFromMonth ? day.year + 1 : day.year
    }

    /// Days left until the year starts (the head-start run-up); 0 once it has begun.
    public static func daysUntilStart(of year: Int, from today: DayKey, calendar: Calendar = .fledge) -> Int {
        max(today.days(to: firstDay(of: year), calendar: calendar), 0)
    }

    public static func firstDay(of year: Int) -> DayKey { DayKey(year: year, month: 1, day: 1) }
    public static func lastDay(of year: Int) -> DayKey { DayKey(year: year, month: 12, day: 31) }

    public static func dayCount(of year: Int, calendar: Calendar = .fledge) -> Int {
        firstDay(of: year).days(to: lastDay(of: year), calendar: calendar) + 1
    }

    /// 1-based day of the year for `today`, clamped to the year: 0 before Jan 1, `dayCount` after Dec 31.
    public static func dayNumber(_ today: DayKey, in year: Int, calendar: Calendar = .fledge) -> Int {
        let number = firstDay(of: year).days(to: today, calendar: calendar) + 1
        return min(max(number, 0), dayCount(of: year, calendar: calendar))
    }

    /// The letter to December opens on Dec 1 of the resolution year (RES-6).
    public static func letterOpens(in year: Int) -> DayKey { DayKey(year: year, month: 12, day: 1) }

    public static func isLetterOpen(today: DayKey, year: Int, kept: Bool) -> Bool {
        kept || today >= letterOpens(in: year)
    }

    /// Wobble week (RES-8): the second Friday of January, when many resolutions start to slip.
    public static func wobbleDay(in year: Int, calendar: Calendar = .fledge) -> DayKey {
        var day = firstDay(of: year)
        var fridays = 0
        while true {
            if calendar.component(.weekday, from: day.date(in: calendar)) == 6 {
                fridays += 1
                if fridays == 2 { return day }
            }
            day = day.adding(days: 1, calendar: calendar)
        }
    }
}

/// Fresh starts instead of failure screens (RES-5). People start goals more at temporal landmarks
/// (Dai, Milkman & Riis), so a lapse is answered with the next Monday or 1st of the month.
public enum FreshStart {
    public enum Landmark: String, Sendable, Equatable {
        case newYear
        case newMonth
        case newWeek
    }

    public struct Offer: Equatable, Sendable {
        public let day: DayKey
        public let landmark: Landmark
    }

    /// Days looked back on to decide whether the resolution has lapsed.
    public static let window = 7
    /// At most this share of planned habit-days met in the window counts as a lapse (2 of 7).
    public static let lapseRate = 2.0 / 7.0

    /// The landmark `day` is, if any. Jan 1 beats the 1st of a month beats a Monday.
    public static func landmark(of day: DayKey, calendar: Calendar = .fledge) -> Landmark? {
        if day.month == 1 && day.day == 1 { return .newYear }
        if day.day == 1 { return .newMonth }
        // Weekday 2 is Monday in the Gregorian calendar, whatever the locale's first weekday.
        if calendar.component(.weekday, from: day.date(in: calendar)) == 2 { return .newWeek }
        return nil
    }

    /// The first landmark after `today` (today itself doesn't count: the user is looking at it now).
    public static func nextLandmark(after today: DayKey, calendar: Calendar = .fledge) -> Offer {
        var day = today.adding(days: 1, calendar: calendar)
        while true {
            if let landmark = landmark(of: day, calendar: calendar) { return Offer(day: day, landmark: landmark) }
            day = day.adding(days: 1, calendar: calendar)
        }
    }

    /// A habit as the lapse check sees it.
    public struct Habit: Sendable {
        public let perWeek: Int
        public let startedOn: DayKey
        public let snapshots: [DaySnapshot]

        public init(perWeek: Int, startedOn: DayKey, snapshots: [DaySnapshot]) {
            self.perWeek = perWeek
            self.startedOn = startedOn
            self.snapshots = snapshots
        }
    }

    /// Every habit counted from the resolution's start (tests and callers without per-habit start days).
    public static func hasLapsed(habits: [(perWeek: Int, snapshots: [DaySnapshot])], startedOn: DayKey, today: DayKey, calendar: Calendar = .fledge) -> Bool {
        hasLapsed(habits: habits.map { Habit(perWeek: $0.perWeek, startedOn: startedOn, snapshots: $0.snapshots) }, startedOn: startedOn, today: today, calendar: calendar)
    }

    /// True when the habits met at most 2 of every 7 planned days in the last week (today excluded, it isn't over).
    /// A habit plans `perWeek` days of the week; rest days don't count against it. Only habits that have been in the
    /// nest for the whole week count (a habit added yesterday can't have lapsed, and Health days from before it
    /// started don't count as met); with none, and in the resolution's first week, nothing has lapsed.
    public static func hasLapsed(habits: [Habit], startedOn: DayKey, today: DayKey, calendar: Calendar = .fledge) -> Bool {
        let first = today.adding(days: -window, calendar: calendar)
        let eligible = habits.filter { $0.startedOn <= first }
        guard !eligible.isEmpty, startedOn <= first else { return false }
        let yesterday = today.adding(days: -1, calendar: calendar)
        var planned = 0
        var met = 0
        for habit in eligible {
            let inWindow = habit.snapshots.filter { $0.day >= first && $0.day <= yesterday }
            let rest = inWindow.filter { $0.status == .skipped }.count
            let habitPlanned = max(min(window - rest, habit.perWeek), 0)
            planned += habitPlanned
            met += min(inWindow.filter { $0.status == .done }.count, habitPlanned)
        }
        guard planned > 0 else { return false }
        return Double(met) / Double(planned) <= lapseRate
    }

    /// Whether to show the fresh-start card today: lapsed, and no fresh start chosen in the last week
    /// (one offer per lapse, not a daily nag).
    public static func shouldOffer(lapsed: Bool, lastFreshStart: DayKey?, today: DayKey, calendar: Calendar = .fledge) -> Bool {
        guard lapsed else { return false }
        guard let lastFreshStart else { return true }
        return lastFreshStart.days(to: today, calendar: calendar) >= window
    }

    /// A smaller goal for "same plan, smaller steps": half, on the stepper's grid, never below one step.
    public static func smallerTarget(_ target: Double, step: Double) -> Double {
        guard step > 0 else { return target }
        let half = (target / 2 / step).rounded(.down) * step
        return min(max(half, step), target)
    }
}

/// Approach goals ("start reading") are kept more often than avoidance goals ("stop scrolling"): 58.9% vs 47.1%
/// after a year (Oscarsson et al. 2020). RES-3 spots avoidance wording so the app can offer a "start" version.
public enum ResolutionFraming {
    /// Leading phrases that make a resolution about not doing something.
    static let avoidancePrefixes = [
        "stop ", "quit ", "no more ", "no ", "less ", "don't ", "dont ", "do not ", "never ", "avoid ", "cut ",
        "cut down ", "give up ", "fewer ", "not ", "stop being "
    ]

    public static func isAvoidance(_ text: String) -> Bool {
        let normalized = normalize(text)
        return avoidancePrefixes.contains { normalized.hasPrefix($0) }
    }

    /// Lowercased, curly apostrophes straightened, single spaces, without a leading "I will" / "I want to".
    static func normalize(_ text: String) -> String {
        var value = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for lead in ["i will ", "i'll ", "i want to ", "i'm going to ", "to "] where value.hasPrefix(lead) {
            value.removeFirst(lead.count)
        }
        return value
    }
}

/// "Never miss twice" (UXR-3): one missed day gets a calm line, not a reset. Daily habits only (weekly ones plan their
/// own rest days); a second missed day in a row is left to the fresh-start offer.
public enum MissCheck {
    public static func missedOnlyYesterday(snapshots: [DaySnapshot], perWeek: Int, startedOn: DayKey, today: DayKey, calendar: Calendar = .fledge) -> Bool {
        guard perWeek >= 7 else { return false }
        let yesterday = today.adding(days: -1, calendar: calendar)
        let dayBefore = today.adding(days: -2, calendar: calendar)
        guard startedOn <= dayBefore else { return false }
        let byDay = Dictionary(snapshots.map { ($0.day, $0.status) }, uniquingKeysWith: { _, last in last })
        func met(_ day: DayKey) -> Bool { [.done, .skipped].contains(byDay[day] ?? .pending) }
        return !met(yesterday) && met(dayBefore)
    }
}

/// A resolution is kept when it had habits and every one of them flew (RES-7).
public enum KeptCheck {
    public static func isKept(habitStates: [HabitState]) -> Bool {
        !habitStates.isEmpty && habitStates.allSatisfy { $0 == .graduated }
    }
}

/// One dot per day of the resolution year (RES-7).
public enum YearMap {
    public enum Dot: Equatable, Sendable {
        /// Not part of the resolution yet (before the start day).
        case before
        /// Every planned habit met (rest days count as met).
        case full
        /// Some met.
        case partial
        /// Planned, nothing met. Drawn as an empty dot, never red.
        case empty
        /// Later days, and today while nothing is met yet.
        case future
    }

    /// One habit on the map: planned from the day it started until the day it flew (after that it's off the plan,
    /// even if Apple Health keeps logging it; tap-to-log graduates aren't logged at all).
    /// A habit done a few days a week (`perWeek` < 7) is only planned on the days it was done or rested, so its
    /// off days don't make a day partial.
    public struct Habit: Sendable {
        public let startedOn: DayKey
        public let endedOn: DayKey?
        public let perWeek: Int
        public let snapshots: [DaySnapshot]

        public init(startedOn: DayKey, endedOn: DayKey? = nil, perWeek: Int = 7, snapshots: [DaySnapshot]) {
            self.startedOn = startedOn
            self.endedOn = endedOn
            self.perWeek = perWeek
            self.snapshots = snapshots
        }
    }

    public static func dots(
        year: Int,
        startDay: DayKey,
        habits: [(startedOn: DayKey, snapshots: [DaySnapshot])],
        today: DayKey,
        calendar: Calendar = .fledge
    ) -> [Dot] {
        dots(year: year, startDay: startDay, habits: habits.map { Habit(startedOn: $0.startedOn, snapshots: $0.snapshots) }, today: today, calendar: calendar)
    }

    public static func dots(year: Int, startDay: DayKey, habits: [Habit], today: DayKey, calendar: Calendar = .fledge) -> [Dot] {
        dots(from: ResolutionYear.firstDay(of: year), through: ResolutionYear.lastDay(of: year), startDay: startDay, habits: habits, today: today, calendar: calendar)
    }

    public static func dots(
        from first: DayKey,
        through last: DayKey,
        startDay: DayKey,
        habits: [(startedOn: DayKey, snapshots: [DaySnapshot])],
        today: DayKey,
        calendar: Calendar = .fledge
    ) -> [Dot] {
        dots(from: first, through: last, startDay: startDay, habits: habits.map { Habit(startedOn: $0.startedOn, snapshots: $0.snapshots) }, today: today, calendar: calendar)
    }

    /// Dots for any run of days, e.g. the first week (UXR-2).
    public static func dots(
        from first: DayKey,
        through last: DayKey,
        startDay: DayKey,
        habits: [Habit],
        today: DayKey,
        calendar: Calendar = .fledge
    ) -> [Dot] {
        let lookups = habits.map { habit in
            (habit, Dictionary(habit.snapshots.map { ($0.day, $0.status) }, uniquingKeysWith: { _, last in last }))
        }
        var dots: [Dot] = []
        var day = first
        while day <= last {
            if day < startDay {
                dots.append(.before)
            } else if day > today {
                dots.append(.future)
            } else {
                let active = lookups.filter { $0.0.startedOn <= day && ($0.0.endedOn.map { day <= $0 } ?? true) }
                let planned = active.filter { $0.0.perWeek >= 7 || [.done, .skipped].contains($0.1[day]) }
                let met = planned.filter { [.done, .skipped].contains($0.1[day]) }.count
                if planned.isEmpty {
                    // Only weekly habits, none done today: nothing was due, but the day was part of the plan.
                    dots.append(day == today ? .future : active.isEmpty ? .before : .empty)
                } else if met == 0 {
                    // Today isn't over: nothing met yet is still to come, not empty.
                    dots.append(day == today ? .future : .empty)
                } else {
                    dots.append(met == planned.count ? .full : .partial)
                }
            }
            day = day.adding(days: 1, calendar: calendar)
        }
        return dots
    }
}
