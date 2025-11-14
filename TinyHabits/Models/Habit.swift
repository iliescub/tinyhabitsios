import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconSystemName: String
    var accentColorKey: String
    var order: Int
    var isArchived: Bool
    var reminderHour: Int?
    var reminderMinute: Int?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry]

    init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String,
        accentColorKey: String,
        order: Int,
        isArchived: Bool = false,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.accentColorKey = accentColorKey
        self.order = order
        self.isArchived = isArchived
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.createdAt = createdAt
        self.entries = []
    }

    func reminderComponents() -> DateComponents? {
        guard let hour = reminderHour, let minute = reminderMinute else { return nil }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return components
    }
}

