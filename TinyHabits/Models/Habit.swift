import Foundation
import SwiftData

struct HabitReminder: Hashable, Codable {
    var hour: Int
    var minute: Int

    var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}


@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconSystemName: String
    var accentColorKey: String
    var order: Int
    var isArchived: Bool
    @Attribute var reminders: [HabitReminder] = []
    var createdAt: Date
    var dailyTarget: Int = 1

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String,
        accentColorKey: String,
        order: Int,
        isArchived: Bool = false,
        reminders: [HabitReminder] = [],
        createdAt: Date = .now,
        dailyTarget: Int = 1
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.accentColorKey = accentColorKey
        self.order = order
        self.isArchived = isArchived
        self.reminders = reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        self.createdAt = createdAt
        self.dailyTarget = max(1, dailyTarget)
    }

    var reminderComponents: [DateComponents] {
        reminders.map(\.dateComponents)
    }
}
