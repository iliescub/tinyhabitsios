import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    private var context: ModelContext?

    @Published var newHabitName: String = ""
    @Published var newHabitIcon: String = "sparkles"
    @Published var newHabitColor: AccentTheme = .blue
    @Published var newHabitTarget: Int = 1
    @Published var hasCompletedOnboarding: Bool = true
    @Published var errorMessage: String?

    func setContext(_ context: ModelContext) {
        self.context = context
    }

    func activeHabits(using habits: [Habit]) -> [Habit] {
        habits.filter { !$0.isArchived }.sorted { $0.order < $1.order }
    }

    func addCustomHabit(currentHabits: [Habit]) {
        guard let context else { return }
        guard newHabitName.trimmingCharacters(in: .whitespaces).isEmpty == false else { return }
        guard activeHabits(using: currentHabits).count < 3 else { return }

        let habit = Habit(
            name: newHabitName.trimmingCharacters(in: .whitespaces),
            iconSystemName: resolvedSymbolName(newHabitIcon),
            accentColorKey: newHabitColor.rawValue,
            order: activeHabits(using: currentHabits).count,
            dailyTarget: newHabitTarget
        )
        context.insert(habit)
        persist()
        resetCustomFields()
    }

    func addCurated(_ curated: CuratedHabit, currentHabits: [Habit]) {
        guard let context else { return }
        guard !isHabitExisting(name: curated.name, in: currentHabits) else { return }
        guard activeHabits(using: currentHabits).count < 3 else { return }

        let model = Habit(
            name: curated.name,
            iconSystemName: curated.icon,
            accentColorKey: curated.color.rawValue,
            order: activeHabits(using: currentHabits).count,
            dailyTarget: curated.defaultTarget
        )
        context.insert(model)
        persist()
    }

    func deleteHabit(_ habit: Habit) {
        guard let context else { return }
        NotificationManager.shared.cancelReminders(for: habit)
        habit.reminders.removeAll()
        context.delete(habit)
        normalizeOrder()
        persist()
    }

    func archiveHabit(_ habit: Habit) {
        guard let context else { return }
        NotificationManager.shared.cancelReminders(for: habit)
        for entry in habit.entries {
            context.delete(entry)
        }
        habit.entries.removeAll()
        habit.reminders.removeAll()
        habit.isArchived = true
        normalizeOrder()
        persist()
    }

    func activateHabit(_ habit: Habit, currentHabits: [Habit]) {
        guard let context else { return }
        guard activeHabits(using: currentHabits).count < 3 else { return }
        habit.isArchived = false
        habit.order = activeHabits(using: currentHabits).count
        persist()
    }

    func normalizedHabits(using habits: [Habit]) -> [Habit] {
        activeHabits(using: habits)
    }

    private func normalizeOrder() {
        guard let context else { return }
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Habit.order, order: .forward)]
        )
        if let orderedHabits = try? context.fetch(descriptor) {
            for (index, habit) in orderedHabits.enumerated() {
                habit.order = index
            }
        }
    }

    private func persist() {
        guard let context, context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            errorMessage = "Could not save changes. Please try again."
            print("SettingsViewModel save error: \(error)")
        }
    }

    private func resetCustomFields() {
        newHabitName = ""
        newHabitIcon = "sparkles"
        newHabitColor = .blue
        newHabitTarget = 1
    }

    private func isHabitExisting(name: String, in habits: [Habit]) -> Bool {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return activeHabits(using: habits).contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target }
    }

    private func resolvedSymbolName(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "circle" }
        return UIImage(systemName: trimmed) == nil ? "circle" : trimmed
    }

    func resetAll(profile: inout ProfileState) {
        guard let context else { return }
        let entryDescriptor = FetchDescriptor<HabitEntry>()
        let habitDescriptor = FetchDescriptor<Habit>()

        let entries = (try? context.fetch(entryDescriptor)) ?? []
        for entry in entries {
            context.delete(entry)
        }

        let allHabits = (try? context.fetch(habitDescriptor)) ?? []
        for habit in allHabits {
            NotificationManager.shared.cancelReminders(for: habit)
            context.delete(habit)
        }

        persist()

        profile = ProfileState()
        hasCompletedOnboarding = false
        resetCustomFields()
    }
}

struct ProfileState {
    var name: String = ""
    var age: Int = 30
    var heightCm: Int = 170
    var weightKg: Int = 70
    var accentRaw: String = AccentTheme.blue.rawValue
}
