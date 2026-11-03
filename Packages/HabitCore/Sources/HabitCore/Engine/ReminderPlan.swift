import Foundation

/// Which local notifications should be pending right now (docs/DESIGN.md §7, NOTIF-1).
/// Rebuilt after every write: a habit already done or resting today gets no reminder today.
public enum ReminderPlan {
    public static let identifierPrefix = "fledge.reminder."
    /// How many days ahead to schedule; refreshed on every launch, write and Health sync.
    public static let horizonDays = 7

    public struct Input: Sendable {
        public let habitID: UUID
        public let name: String
        public let reminderMinutes: Int?
        public let todayStatus: EntryStatus
        public let remainingText: String?
        /// The if-then cue (RES-4); reminders lead with it: "After lunch: Walk".
        public let cue: String

        public init(habitID: UUID, name: String, reminderMinutes: Int?, todayStatus: EntryStatus, remainingText: String? = nil, cue: String = "") {
            self.habitID = habitID
            self.name = name
            self.reminderMinutes = reminderMinutes
            self.todayStatus = todayStatus
            self.remainingText = remainingText
            self.cue = cue
        }

        /// "After lunch: Walk", or just the name without a cue (UXR-6).
        public var reminderTitle: String {
            let trimmed = cue.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? name : "\(trimmed): \(name)"
        }
    }

    public struct Reminder: Equatable, Sendable {
        public let identifier: String
        public let habitID: UUID
        public let fireDate: Date
        public let title: String
        public let body: String
    }

    public static func reminders(
        for habits: [Input],
        today: DayKey,
        now: Date,
        calendar: Calendar = .fledge
    ) -> [Reminder] {
        var result: [Reminder] = []
        for habit in habits {
            guard let minutes = habit.reminderMinutes else { continue }
            for offset in 0..<horizonDays {
                let day = today.adding(days: offset, calendar: calendar)
                if offset == 0 && habit.todayStatus != .pending { continue }
                let midnight = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? day.date(in: calendar)
                guard let fire = calendar.date(byAdding: .minute, value: minutes, to: midnight), fire > now else { continue }
                let body: String
                if offset == 0, let remaining = habit.remainingText {
                    body = "Still in the nest today. \(remaining)"
                } else {
                    body = "Still in the nest today."
                }
                result.append(Reminder(
                    identifier: "\(identifierPrefix)\(habit.habitID.uuidString).\(day.rawValue)",
                    habitID: habit.habitID,
                    fireDate: fire,
                    title: habit.reminderTitle,
                    body: body
                ))
            }
        }
        return result.sorted { $0.fireDate < $1.fireDate }
    }

    public static let momentIdentifierPrefix = "fledge.moment."

    /// The resolution moments (RES-6, RES-8), at most one each: the letter on 1 December at 9:00 (when one was written),
    /// and the wobble-week check-in on the second Friday of January at 10:00 (when the resolution started before it).
    /// Only while the resolution is in progress, and only in the future.
    public static func resolutionMoments(
        resolutionText: String,
        year: Int,
        startDay: DayKey,
        isActive: Bool,
        hasLetter: Bool,
        now: Date,
        calendar: Calendar = .fledge
    ) -> [Reminder] {
        guard isActive else { return [] }
        let none = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        func at(_ day: DayKey, hour: Int) -> Date? {
            calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour))
        }
        var result: [Reminder] = []
        let wobble = ResolutionYear.wobbleDay(in: year, calendar: calendar)
        if startDay < wobble, let fire = at(wobble, hour: 10), fire > now {
            result.append(Reminder(
                identifier: "\(momentIdentifierPrefix)wobble.\(year)", habitID: none, fireDate: fire,
                title: resolutionText,
                body: "Most resolutions wobble this week. Two minutes still counts today."
            ))
        }
        let letterDay = ResolutionYear.letterOpens(in: year)
        if hasLetter, let fire = at(letterDay, hour: 9), fire > now {
            result.append(Reminder(
                identifier: "\(momentIdentifierPrefix)letter.\(year)", habitID: none, fireDate: fire,
                title: "A letter from January",
                body: "The note you wrote about \u{201C}\(resolutionText)\u{201D} is ready to open."
            ))
        }
        return result
    }

    public static let summaryIdentifierPrefix = "fledge.summary."

    /// Optional evening summary (SET-1): today only if something is still open, then a generic check-in
    /// for the following days (their state is unknown until they happen).
    public static func eveningSummaries(
        minutes: Int?,
        habits: [Input],
        today: DayKey,
        now: Date,
        calendar: Calendar = .fledge
    ) -> [Reminder] {
        guard let minutes, !habits.isEmpty else { return [] }
        let done = habits.filter { $0.todayStatus == .done }.count
        let open = habits.filter { $0.todayStatus == .pending }
        var result: [Reminder] = []
        for offset in 0..<horizonDays {
            let day = today.adding(days: offset, calendar: calendar)
            if offset == 0 && open.isEmpty { continue }
            let midnight = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? day.date(in: calendar)
            guard let fire = calendar.date(byAdding: .minute, value: minutes, to: midnight), fire > now else { continue }
            let body: String
            if offset == 0 {
                let next = open.first.map { habit in habit.remainingText.map { "\(habit.name): \($0)" } ?? "\(habit.name) is still open." } ?? ""
                body = "\(done) of \(habits.count) done. \(next)"
            } else {
                body = "How did your three habits go today?"
            }
            result.append(Reminder(
                identifier: "\(summaryIdentifierPrefix)\(day.rawValue)",
                habitID: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                fireDate: fire,
                title: "Yearling",
                body: body
            ))
        }
        return result
    }
}
