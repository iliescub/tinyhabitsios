import AppIntents
import Foundation
import SwiftData
import WidgetKit
import HabitCore
import FledgeUI

// Compiled into both the app and the widget extension (Shared/ is in both targets).

/// A habit as Siri, Shortcuts, widgets and controls see it.
struct HabitEntity: AppEntity, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static let defaultQuery = HabitEntityQuery()

    let id: UUID
    let name: String
    let symbol: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: symbol))
    }

    init(id: UUID, name: String, symbol: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
    }

    init(_ habit: Habit) {
        self.init(id: habit.id, name: habit.name, symbol: habit.symbol)
    }
}

struct HabitEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        let context = try IntentStore.context()
        return identifiers.compactMap { id in (try? context.habit(id: id)).flatMap { $0 }.map(HabitEntity.init) }
    }

    @MainActor
    func suggestedEntities() async throws -> [HabitEntity] {
        try IntentStore.context().activeHabits().map(HabitEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [HabitEntity] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}

/// Opens the shared store for an intent and refreshes everything that depends on it afterwards.
@MainActor
enum IntentStore {
    static func context() throws -> ModelContext {
        ModelContext(try SharedStore.makeContainer())
    }

    /// Runs a write, then tells the app (marker), reminders, widgets and controls.
    static func write<T>(_ body: (ModelContext) throws -> T) async throws -> T {
        let context = try context()
        let result = try body(context)
        FledgeSettings.markExternalWrite()
        await Reminders.reconcile(context: context)
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        return result
    }
}

// MARK: - Intents

struct CompleteHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Habit Done"
    static let description = IntentDescription("Marks a habit done for today in Fledge.")

    @Parameter(title: "Habit") var habit: HabitEntity

    init() {}
    init(habit: HabitEntity) { self.habit = habit }

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$habit) done")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = habit.id
        try await IntentStore.write { try $0.setDone(true, habitID: id, on: .today(), by: .intent) }
        return .result(dialog: "\(habit.name) is done for today.")
    }
}

/// Used by the widgets' ring buttons: done ↔ not done.
struct ToggleHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Habit"
    static let isDiscoverable = false

    @Parameter(title: "Habit") var habit: HabitEntity

    init() {}
    init(habit: HabitEntity) { self.habit = habit }

    @MainActor
    func perform() async throws -> some IntentResult {
        let id = habit.id
        try await IntentStore.write { context in
            let today = DayKey.today()
            let isDone = try context.log(for: id, on: today)?.status == .done
            try context.setDone(!isDone, habitID: id, on: today, by: .widget)
        }
        return .result()
    }
}

struct LogProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Habit Progress"
    static let description = IntentDescription("Adds an amount, such as minutes or pages, to today's progress.")

    @Parameter(title: "Habit") var habit: HabitEntity
    @Parameter(title: "Amount", inclusiveRange: (0.1, 100_000)) var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) to \(\.$habit)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = habit.id
        let value = amount
        try await IntentStore.write { try $0.addAmount(value, habitID: id, on: .today()) }
        return .result(dialog: "Logged for \(habit.name).")
    }
}

struct SkipTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Take a Rest Day"
    static let description = IntentDescription("Marks today as a rest day for a habit.")

    @Parameter(title: "Habit") var habit: HabitEntity

    init() {}
    init(habit: HabitEntity) { self.habit = habit }

    static var parameterSummary: some ParameterSummary {
        Summary("Rest day for \(\.$habit)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = habit.id
        do {
            try await IntentStore.write { try $0.skip(habitID: id, on: .today()) }
            return .result(dialog: "Rest day for \(habit.name). See you tomorrow.")
        } catch HabitStoreError.noRestDaysLeft {
            return .result(dialog: "\(habit.name) has used this month's rest days.")
        }
    }
}

struct HabitStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Habit Status"
    static let description = IntentDescription("Tells you how today's habits are going.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = NestSnapshot(context: try IntentStore.context(), day: .today())
        return .result(dialog: "\(snapshot.spokenSummary)")
    }
}

// MARK: - Configuration

/// Lets the user pick which habit a Lock Screen ring shows.
struct SelectHabitIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Habit"
    static let description = IntentDescription("Pick the habit to show.")

    @Parameter(title: "Habit") var habit: HabitEntity?

    init() {}
    init(habit: HabitEntity?) { self.habit = habit }
}

/// Lets the user pick which habit a Control Center control marks done.
struct SelectHabitControlIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Habit"
    static let description = IntentDescription("Pick the habit this control marks done.")

    @Parameter(title: "Habit") var habit: HabitEntity?

    init() {}
    init(habit: HabitEntity?) { self.habit = habit }
}

/// Control Center toggle: sets a habit done or not done.
struct SetHabitDoneIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Set Habit Done"
    static let isDiscoverable = false

    @Parameter(title: "Habit") var habit: HabitEntity?
    @Parameter(title: "Done") var value: Bool

    init() {}
    init(habit: HabitEntity?) { self.habit = habit }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = habit?.id else { return .result() }
        let done = value
        try await IntentStore.write { try $0.setDone(done, habitID: id, on: .today(), by: .intent) }
        return .result()
    }
}
