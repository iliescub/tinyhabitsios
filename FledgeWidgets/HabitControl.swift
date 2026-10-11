import AppIntents
import SwiftData
import SwiftUI
import WidgetKit
import HabitCore

/// Control Center / Lock Screen control: "Mark Read done" (WID-4).
struct HabitControl: ControlWidget {
    static let kind = "com.smartapps.TinyHabits.habitControl"

    var body: some ControlWidgetConfiguration {
        // Free for everyone: control templates can't switch on Pro status, and a dead toggle would be worse.
        AppIntentControlConfiguration(kind: Self.kind, provider: HabitControlProvider()) { value in
            ControlWidgetToggle(isOn: value.isDone, action: SetHabitDoneIntent(habit: value.habit)) {
                Label(value.habit?.name ?? "Choose a habit", systemImage: value.isDone ? "checkmark.circle.fill" : (value.habit?.symbol ?? "bird"))
            }
        }
        .displayName("Mark habit done")
        .description("Mark one of your habits done without opening Fledge.")
    }
}

struct HabitControlValue {
    let habit: HabitEntity?
    let isDone: Bool
}

struct HabitControlProvider: AppIntentControlValueProvider {
    func previewValue(configuration: SelectHabitControlIntent) -> HabitControlValue {
        HabitControlValue(habit: configuration.habit ?? HabitEntity(id: UUID(), name: "Read", symbol: "book.fill"), isDone: false)
    }

    @MainActor
    func currentValue(configuration: SelectHabitControlIntent) async throws -> HabitControlValue {
        let context = try IntentStore.context()
        let habit: HabitEntity?
        if let chosen = configuration.habit {
            habit = chosen
        } else {
            habit = try context.activeHabits().first { !$0.source.isAuto }.map(HabitEntity.init)
        }
        guard let habit else { return HabitControlValue(habit: nil, isDone: false) }
        let isDone = try context.log(for: habit.id, on: .today())?.status == .done
        return HabitControlValue(habit: habit, isDone: isDone)
    }
}
