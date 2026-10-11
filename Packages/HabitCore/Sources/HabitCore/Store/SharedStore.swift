import Foundation
import SwiftData

/// One SwiftData store in the App Group container, shared by the app, widgets, controls and intents.
public enum SharedStore {
    /// Must match `com.apple.security.application-groups` in the app and widget entitlements.
    public static let appGroupID = "group.com.smartapps.TinyHabits"

    public static func makeContainer(inMemory: Bool = false, appGroupID: String = appGroupID) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID), cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: HabitMigrationPlan.self, configurations: [configuration])
    }
}

public enum HabitStoreError: Error, Equatable {
    /// All three slots are taken; graduate or pause a habit first.
    case nestFull
    case habitNotFound
}

/// The single write API. The app calls these on its main context; `HabitWriter` runs the same code
/// off the main actor for widgets, intents and HealthKit background delivery.
extension ModelContext {
    public func activeHabits() throws -> [Habit] {
        let active = HabitState.active.rawValue
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.stateRaw == active })
        return try fetch(descriptor).sorted { ($0.slot ?? .max) < ($1.slot ?? .max) }
    }

    public func habit(id: UUID) throws -> Habit? {
        try fetch(FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })).first
    }

    /// Adds a habit into the lowest free slot. Throws `.nestFull` when three habits are active.
    @discardableResult
    public func addHabit(
        name: String,
        symbol: String,
        colorKey: String,
        source: HabitSourceID,
        target: Double,
        unit: String,
        perWeek: Int = 7,
        packID: String = "essentials",
        startedAt: Date = .now
    ) throws -> Habit {
        let occupied = Set(try activeHabits().compactMap(\.slot))
        guard let slot = SlotPolicy.nextFreeSlot(occupied: occupied) else { throw HabitStoreError.nestFull }
        let habit = Habit(
            name: name, symbol: symbol, colorKey: colorKey, source: source, target: target, unit: unit,
            perWeek: perWeek, slot: slot, packID: packID, startedAt: startedAt
        )
        insert(habit)
        try save()
        return habit
    }

    @discardableResult
    public func addHabit(from template: Pack.Template, colorKey: String, packID: String) throws -> Habit {
        try addHabit(
            name: template.name, symbol: template.symbol, colorKey: colorKey, source: template.source,
            target: template.target, unit: template.unit, perWeek: template.perWeek ?? 7, packID: packID
        )
    }

    /// Frees the slot; history is kept.
    public func pause(habitID: UUID) throws {
        guard let habit = try habit(id: habitID) else { throw HabitStoreError.habitNotFound }
        habit.state = .paused
        habit.slot = nil
        try save()
    }

    /// Moves a paused or graduated habit back into a free slot.
    public func resume(habitID: UUID) throws {
        guard let habit = try habit(id: habitID) else { throw HabitStoreError.habitNotFound }
        guard habit.state != .active else { return }
        let occupied = Set(try activeHabits().compactMap(\.slot))
        guard let slot = SlotPolicy.nextFreeSlot(occupied: occupied) else { throw HabitStoreError.nestFull }
        habit.state = .active
        habit.slot = slot
        habit.graduatedAt = nil
        try save()
    }

    public func graduate(habitID: UUID, on date: Date = .now) throws {
        guard let habit = try habit(id: habitID) else { throw HabitStoreError.habitNotFound }
        habit.state = .graduated
        habit.slot = nil
        habit.graduatedAt = date
        try save()
    }

    public func deleteHabit(habitID: UUID) throws {
        guard let habit = try habit(id: habitID) else { return }
        delete(habit)
        try save()
    }

    /// Returns the log for `habitID` on `day`, creating it if needed (not saved).
    public func log(for habitID: UUID, on day: DayKey) throws -> DayLog? {
        let key = day.rawValue
        let existing = FetchDescriptor<DayLog>(predicate: #Predicate { $0.dayKey == key && $0.habit?.id == habitID })
        if let log = try fetch(existing).first {
            return log
        }
        guard let habit = try habit(id: habitID) else { return nil }
        let log = DayLog(dayKey: day, habit: habit)
        insert(log)
        return log
    }

    /// Marks a day done (or back to pending) from a tap, widget or intent.
    public func setDone(_ done: Bool, habitID: UUID, on day: DayKey, by actor: CompletedBy) throws {
        guard let log = try log(for: habitID, on: day) else { return }
        log.status = done ? .done : .pending
        log.completedBy = done ? actor : nil
        if !done { log.value = 0 }
        log.updatedAt = .now
        try save()
    }

    public func skip(habitID: UUID, on day: DayKey) throws {
        guard let log = try log(for: habitID, on: day) else { return }
        log.status = .skipped
        log.updatedAt = .now
        try save()
    }

    /// Stores a measured value (HealthKit) or a manual amount, then re-evaluates the day.
    public func record(value: Double, habitID: UUID, on day: DayKey, by actor: CompletedBy) throws {
        guard let log = try log(for: habitID, on: day), let habit = log.habit else { return }
        log.value = value
        let result = DayEvaluator.evaluate(value: value, target: habit.target, stored: log.status, completedBy: log.completedBy)
        if result.status != log.status {
            log.status = result.status
            log.completedBy = result.status == .done ? actor : nil
        }
        log.updatedAt = .now
        try save()
    }
}

/// Off-main-actor writer for widgets, App Intents and HealthKit background delivery.
@ModelActor
public actor HabitWriter {
    public func setDone(_ done: Bool, habitID: UUID, on day: DayKey, by actor: CompletedBy) throws {
        try modelContext.setDone(done, habitID: habitID, on: day, by: actor)
    }

    public func skip(habitID: UUID, on day: DayKey) throws {
        try modelContext.skip(habitID: habitID, on: day)
    }

    public func record(value: Double, habitID: UUID, on day: DayKey, by actor: CompletedBy) throws {
        try modelContext.record(value: value, habitID: habitID, on: day, by: actor)
    }
}
