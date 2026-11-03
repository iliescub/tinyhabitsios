import SwiftUI
import HabitCore

/// What the Today header says about the resolution (RES-7), from model values only so it's unit-testable.
public struct ResolutionHeaderModel: Equatable, Sendable {
    /// "In 2027 I'm sleeping better" for a template, "My 2027 resolution: Learn the cello" for a custom one.
    public let sentence: String
    /// "Head start · 61 days to 2027", "Day 12 of 365 · 1 of 3 flown", "Kept".
    public let progressLine: String
    public let dots: [YearMap.Dot]
    public let isKept: Bool
    /// Why it matters, in the user's words (UXR-4); empty when skipped.
    public let why: String
    /// Days 1–7 of the resolution (UXR-2): those days and their dots replace the year strip.
    public let firstWeekDays: [DayKey]
    public let firstWeekDots: [YearMap.Dot]
    public var isFirstWeek: Bool { !firstWeekDays.isEmpty }

    public init(
        text: String,
        templateSentence: String?,
        why: String = "",
        year: Int,
        startDay: DayKey,
        isKept: Bool,
        habits: [(startedOn: DayKey, snapshots: [DaySnapshot], state: HabitState)],
        today: DayKey,
        calendar: Calendar = .fledge
    ) {
        self.init(
            text: text, templateSentence: templateSentence, why: why, year: year, startDay: startDay, isKept: isKept,
            habits: habits.map { ($0.startedOn, nil, $0.snapshots, $0.state) }, today: today, calendar: calendar
        )
    }

    /// - Parameter habits: `endedOn` is the day a habit flew; it's off the plan after that (see `YearMap.Habit`).
    public init(
        text: String,
        templateSentence: String?,
        why: String = "",
        year: Int,
        startDay: DayKey,
        isKept: Bool,
        habits: [(startedOn: DayKey, endedOn: DayKey?, snapshots: [DaySnapshot], state: HabitState)],
        today: DayKey,
        calendar: Calendar = .fledge
    ) {
        self.init(
            text: text, templateSentence: templateSentence, why: why, year: year, startDay: startDay, isKept: isKept,
            mapHabits: habits.filter { $0.state != .paused }.map { YearMap.Habit(startedOn: $0.startedOn, endedOn: $0.endedOn, snapshots: $0.snapshots) },
            states: habits.map(\.state), today: today, calendar: calendar
        )
    }

    /// - Parameters:
    ///   - mapHabits: the habits on the year map (paused ones left out: they're off the plan).
    ///   - states: every habit of the resolution; paused ones count as not flown yet.
    public init(
        text: String,
        templateSentence: String?,
        why: String = "",
        year: Int,
        startDay: DayKey,
        isKept: Bool,
        mapHabits: [YearMap.Habit],
        states: [HabitState],
        today: DayKey,
        calendar: Calendar = .fledge
    ) {
        let yearText = String(year)
        if let templateSentence, !templateSentence.isEmpty {
            sentence = "In \(yearText) I'm \(templateSentence)"
        } else {
            sentence = "My \(yearText) resolution: \(text)"
        }
        self.isKept = isKept
        self.why = why.trimmingCharacters(in: .whitespacesAndNewlines)
        let dayIndex = startDay.days(to: today, calendar: calendar)
        if !isKept, (0..<7).contains(dayIndex) {
            let days = (0..<7).map { startDay.adding(days: $0, calendar: calendar) }
            firstWeekDays = days
            firstWeekDots = YearMap.dots(
                from: days[0], through: days[6], startDay: startDay, habits: mapHabits, today: today, calendar: calendar
            )
        } else {
            firstWeekDays = []
            firstWeekDots = []
        }
        // Paused habits still belong to the resolution (it isn't kept until they fly too), so they're counted.
        let flown = states.filter { $0 == .graduated }.count
        let flownText = states.isEmpty ? "No habits yet" : "\(flown) of \(states.count) flown"
        if isKept {
            progressLine = "Kept · every habit flew"
        } else if (0..<7).contains(dayIndex) {
            progressLine = "First week · day \(dayIndex + 1) of 7 · \(flownText)"
        } else if let lead = Optional(ResolutionYear.daysUntilStart(of: year, from: today, calendar: calendar)), lead > 0 {
            progressLine = "Head start · \(lead) \(lead == 1 ? "day" : "days") to \(yearText) · \(flownText)"
        } else {
            let number = ResolutionYear.dayNumber(today, in: year, calendar: calendar)
            progressLine = "Day \(number) of \(ResolutionYear.dayCount(of: year, calendar: calendar)) · \(flownText)"
        }
        dots = YearMap.dots(
            year: year, startDay: max(startDay, ResolutionYear.firstDay(of: year)), habits: mapHabits, today: today, calendar: calendar
        )
    }

    /// For VoiceOver: "Year map: 40 days with every habit met, 12 with some."
    public var dotsSummary: String {
        let full = dots.filter { $0 == .full }.count
        let partial = dots.filter { $0 == .partial }.count
        return "Year map: \(full) \(full == 1 ? "day" : "days") with every habit met, \(partial) with some."
    }
}

/// One thin row of 365 marks, January to December: the year at a glance (RES-7). Empty days are faint, never red.
public struct YearStrip: View {
    public let dots: [YearMap.Dot]
    public var color: Color

    public init(dots: [YearMap.Dot], color: Color = FledgeTheme.Palette.meadow) {
        self.dots = dots
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            guard !dots.isEmpty else { return }
            let step = size.width / CGFloat(dots.count)
            let width = max(step * 0.7, 0.5)
            for (index, dot) in dots.enumerated() {
                let style: (Color, CGFloat)? = switch dot {
                case .full: (color, 1)
                case .partial: (color.opacity(0.5), 0.75)
                case .empty: (FledgeTheme.Palette.ink2.opacity(0.25), 0.35)
                case .future: (FledgeTheme.Palette.ink.opacity(0.08), 0.35)
                case .before: nil
                }
                guard let (fill, height) = style else { continue }
                let barHeight = size.height * height
                let rect = CGRect(x: CGFloat(index) * step, y: (size.height - barHeight) / 2, width: width, height: barHeight)
                context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(fill))
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}

/// The year as 12 month columns × up to 31 days (UXR-5), built from `YearMap` dots.
public struct YearGridModel: Equatable, Sendable {
    public struct Month: Equatable, Sendable {
        /// 1...12
        public let number: Int
        /// One entry per day of the month.
        public let dots: [YearMap.Dot]
        /// Days with every habit met.
        public var fullDays: Int { dots.filter { $0 == .full }.count }
        /// Days met at least partly.
        public var metDays: Int { dots.filter { $0 == .full || $0 == .partial }.count }
    }

    public let year: Int
    public let months: [Month]

    /// - Parameter dots: one per day of `year`, January 1 first (as `YearMap.dots(year:…)` returns them).
    public init(year: Int, dots: [YearMap.Dot], calendar: Calendar = .fledge) {
        self.year = year
        var months: [Month] = []
        var index = 0
        for month in 1...12 {
            let first = DayKey(year: year, month: month, day: 1)
            let next = month == 12 ? DayKey(year: year + 1, month: 1, day: 1) : DayKey(year: year, month: month + 1, day: 1)
            let count = first.days(to: next, calendar: calendar)
            let end = min(index + count, dots.count)
            months.append(Month(number: month, dots: index < end ? Array(dots[index..<end]) : []))
            index += count
        }
        self.months = months
    }

    public var fullDays: Int { months.reduce(0) { $0 + $1.fullDays } }
    public var metDays: Int { months.reduce(0) { $0 + $1.metDays } }
}

/// The Flown shelf grouped by resolution (RES-7): newest year first, kept ones marked; habits that served no
/// resolution come last. One group without a resolution needs no headers at all.
public enum FlownGroups {
    public struct ResolutionInfo: Equatable, Sendable {
        public let text: String
        public let year: Int
        public let isKept: Bool
        public let createdAt: Date

        public init(text: String, year: Int, isKept: Bool, createdAt: Date) {
            self.text = text
            self.year = year
            self.isKept = isKept
            self.createdAt = createdAt
        }
    }

    public struct Group<Item> {
        /// nil for habits outside any resolution.
        public let resolutionID: UUID?
        /// "Sleep better · 2027 · Kept"; nil when no headers are needed.
        public let title: String?
        public let items: [Item]
    }

    public static func groups<Item>(
        _ items: [Item],
        resolutionID: (Item) -> UUID?,
        resolutions: [UUID: ResolutionInfo]
    ) -> [Group<Item>] {
        var byResolution: [UUID: [Item]] = [:]
        var loose: [Item] = []
        for item in items {
            if let id = resolutionID(item), resolutions[id] != nil {
                byResolution[id, default: []].append(item)
            } else {
                loose.append(item)
            }
        }
        if byResolution.isEmpty {
            return loose.isEmpty ? [] : [Group(resolutionID: nil, title: nil, items: loose)]
        }
        let ordered = byResolution.keys.sorted { lhs, rhs in
            let a = resolutions[lhs]!, b = resolutions[rhs]!
            return a.year != b.year ? a.year > b.year : a.createdAt > b.createdAt
        }
        var result = ordered.map { id -> Group<Item> in
            let info = resolutions[id]!
            let title = "\(info.text) · \(info.year)" + (info.isKept ? " · Kept" : "")
            return Group(resolutionID: id, title: title, items: byResolution[id]!)
        }
        if !loose.isEmpty {
            result.append(Group(resolutionID: nil, title: "Other habits", items: loose))
        }
        return result
    }
}

// MARK: - From stored models

extension YearMap.Habit {
    /// A stored habit on the year map: from its start day until the day it flew, at its cadence.
    public init(_ habit: SchemaV2.Habit, dayEndHour: Int = FledgeSettings.dayEndHour, calendar: Calendar = .fledge) {
        self.init(
            startedOn: DayKey(habit.startedAt, calendar: calendar, dayEndHour: dayEndHour),
            endedOn: habit.graduatedAt.map { DayKey($0, calendar: calendar, dayEndHour: dayEndHour) },
            perWeek: habit.perWeek,
            snapshots: habit.logs?.compactMap(\.snapshot) ?? []
        )
    }
}

extension ResolutionHeaderModel {
    /// The one place a stored resolution and its habits become the Today card, the resolution sheet and Kept.
    /// Nil without a valid start day.
    public init?(
        resolution: Resolution, habits: [SchemaV2.Habit], today: DayKey,
        dayEndHour: Int = FledgeSettings.dayEndHour, calendar: Calendar = .fledge
    ) {
        guard let start = resolution.startDay else { return nil }
        let own = habits.filter { $0.resolutionID == resolution.id }
        let sentence = (try? ResolutionLibrary.template(id: resolution.templateID))??.sentence
        self.init(
            text: resolution.text, templateSentence: sentence, why: resolution.why, year: resolution.year,
            startDay: start, isKept: resolution.state == .kept,
            mapHabits: own.filter { $0.state != .paused }.map { YearMap.Habit($0, dayEndHour: dayEndHour, calendar: calendar) },
            states: own.map(\.state), today: today, calendar: calendar
        )
    }
}
