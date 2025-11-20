import Foundation
import SwiftData

enum HabitStatus: Int, Codable {
    case pending = 0
    case done = 1
    case skipped = 2
}

@Model
final class HabitEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var statusRaw: Int
    var progressValue: Int

    @Relationship var habit: Habit

    var status: HabitStatus {
        get { HabitStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
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
