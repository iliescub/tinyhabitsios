import Foundation
import SwiftData

/// One SwiftData store in the App Group container, shared by the app, widgets, controls and intents.
public enum SharedStore {
    /// Replace with the real identifier once the App Group exists in the developer portal.
    public static let appGroupID = "group.com.fledgehabits.shared"

    public static func makeContainer(inMemory: Bool = false, appGroupID: String = appGroupID) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID), cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: HabitMigrationPlan.self, configurations: [configuration])
    }
}

/// The single writer. Every mutation (app, widget, intent, HealthKit sync) goes through here.
@ModelActor
public actor HabitWriter {
    /// Returns the log for `habitID` on `day`, creating it if needed.
    @discardableResult
    public func log(for habitID: UUID, on day: DayKey) throws -> DayLog? {
        let key = day.rawValue
        let existing = FetchDescriptor<DayLog>(predicate: #Predicate { $0.dayKey == key && $0.habit?.id == habitID })
        if let log = try modelContext.fetch(existing).first {
            return log
        }
        let habitQuery = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
        guard let habit = try modelContext.fetch(habitQuery).first else { return nil }
        let log = DayLog(dayKey: day, habit: habit)
        modelContext.insert(log)
        return log
    }

    /// Marks a day done (or back to pending) from a tap, widget or intent.
    public func setDone(_ done: Bool, habitID: UUID, on day: DayKey, by actor: CompletedBy) throws {
        guard let log = try log(for: habitID, on: day) else { return }
        log.status = done ? .done : .pending
        log.completedBy = done ? actor : nil
        if !done { log.value = 0 }
        log.updatedAt = .now
        try modelContext.save()
    }

    public func skip(habitID: UUID, on day: DayKey) throws {
        guard let log = try log(for: habitID, on: day) else { return }
        log.status = .skipped
        log.updatedAt = .now
        try modelContext.save()
    }

    /// Stores a measured value (HealthKit) or a manual partial amount, then re-evaluates the day.
    public func record(value: Double, habitID: UUID, on day: DayKey, by actor: CompletedBy) throws {
        guard let log = try log(for: habitID, on: day), let habit = log.habit else { return }
        log.value = value
        let result = DayEvaluator.evaluate(value: value, target: habit.target, stored: log.status, completedBy: log.completedBy)
        if result.status != log.status {
            log.status = result.status
            log.completedBy = result.status == .done ? actor : nil
        }
        log.updatedAt = .now
        try modelContext.save()
    }
}
