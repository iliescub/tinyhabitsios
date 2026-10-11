import Foundation
import Combine
import SwiftData

@MainActor
final class HabitStore: ObservableObject {
    static let shared = HabitStore()
    private init() {}

    func activeHabits(using context: ModelContext) -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: Habit.activeHabitsPredicate,
            sortBy: [SortDescriptor(\Habit.order, order: .forward)]
        )
        let fetched = (try? context.fetch(descriptor)) ?? []
        return fetched.sorted { $0.order < $1.order }
    }

    func todayEntry(for habit: Habit, using context: ModelContext, on date: Date = Date()) -> HabitEntry {
        let calendar = Calendar.current
        let habitID = habit.id
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)

        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in
                entry.habit?.id == habitID &&
                entry.date >= start &&
                entry.date < end
            },
            sortBy: [SortDescriptor(\HabitEntry.date, order: .reverse)]
        )

        // Check for existing entry
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        // Create new entry
        let entry = HabitEntry(date: date, status: .pending, habit: habit, progressValue: 0)

        // Double-check before insert to catch any entries created between first fetch and now
        // This is extra safety even though @MainActor should serialize access
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        context.insert(entry)

        // Save immediately to persist the entry
        do {
            try context.save()
        } catch {
            // If save fails (e.g., due to constraint violation or conflict),
            // fetch again to get the entry that was successfully saved
            print("HabitStore save error: \(error)")
            if let existing = try? context.fetch(descriptor).first {
                // Remove the failed entry from context to avoid confusion
                context.delete(entry)
                return existing
            }
        }

        return entry
    }

    func persist(_ context: ModelContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("HabitStore save error: \(error)")
        }
    }
}
