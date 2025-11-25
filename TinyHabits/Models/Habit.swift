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
//    var createdAt: Date
    var dailyTarget: Int = 1

    @Relationship(deleteRule: .cascade)
    var entries: [HabitEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String,
        accentColorKey: String,
        order: Int,
        isArchived: Bool = false,
        reminders: [HabitReminder] = [],
//        createdAt: Date = .now,
        dailyTarget: Int = 1
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.accentColorKey = accentColorKey
        self.order = order
        self.isArchived = isArchived
        self.reminders = reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
//        self.createdAt = createdAt
        self.dailyTarget = max(1, dailyTarget)
    }

    var reminderComponents: [DateComponents] {
        reminders.map(\.dateComponents)
    }
}

extension Habit {
    static var curatedTemplates: [Habit] {
        [
            Habit(name: "Drink Water", iconSystemName: "drop.fill", accentColorKey: AccentTheme.blue.rawValue, order: 0, dailyTarget: 2000),
            Habit(name: "Stretch", iconSystemName: "figure.cooldown", accentColorKey: AccentTheme.green.rawValue, order: 1, dailyTarget: 5),
            Habit(name: "Read 10 Minutes", iconSystemName: "book.fill", accentColorKey: AccentTheme.orange.rawValue, order: 2, dailyTarget: 30),
            Habit(name: "Walk", iconSystemName: "figure.walk", accentColorKey: AccentTheme.green.rawValue, order: 3, dailyTarget: 5000),
            Habit(name: "Meditate", iconSystemName: "sparkles", accentColorKey: AccentTheme.blue.rawValue, order: 4, dailyTarget: 20)
        ]
    }
}
