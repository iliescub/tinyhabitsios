import Foundation
import SwiftData

enum HabitStatus: Int, Codable {
    case pending = 0
    case done = 1
    case skipped = 2
}

enum HabitEntryError: Error {
    case missingHabit

    var localizedDescription: String {
        switch self {
        case .missingHabit:
            return "Habit entry is missing its associated habit"
        }
    }
}

@Model
final class HabitEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var statusRaw: Int
    var progressValue: Int

    /// The associated habit for this entry.
    /// Note: This is optional due to SwiftData inverse relationship requirements,
    /// but should never be nil in practice. Use `validatedHabit()` for safer access.
    @Relationship(inverse: \Habit.entries) var habit: Habit?

    var status: HabitStatus {
        get { HabitStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// Returns the associated habit or throws an error if nil.
    /// This should never fail in normal operation as every entry must have a habit.
    func validatedHabit() throws -> Habit {
        guard let habit = habit else {
            throw HabitEntryError.missingHabit
        }
        return habit
    }

    init(
        id: UUID = UUID(),
        date: Date,
        status: HabitStatus,
        habit: Habit,
        progressValue: Int = 0
    ) {
        self.id = id
        self.date = date
        self.statusRaw = status.rawValue
        self.habit = habit
        self.progressValue = progressValue
    }
}
