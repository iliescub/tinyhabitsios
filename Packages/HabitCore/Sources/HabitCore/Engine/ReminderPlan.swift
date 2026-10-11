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

        public init(habitID: UUID, name: String, reminderMinutes: Int?, todayStatus: EntryStatus, remainingText: String? = nil) {
            self.habitID = habitID
            self.name = name
            self.reminderMinutes = reminderMinutes
            self.todayStatus = todayStatus
            self.remainingText = remainingText
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
        calendar: Calendar = .current
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
                    title: habit.name,
                    body: body
                ))
            }
        }
        return result.sorted { $0.fireDate < $1.fireDate }
    }
}
