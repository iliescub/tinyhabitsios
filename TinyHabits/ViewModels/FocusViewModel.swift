import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
final class FocusViewModel: ObservableObject {
    private var context: ModelContext?
    @Published var quote: String = ""
    @Published var errorMessage: String?

    init() {}
    init(context: ModelContext) { self.context = context }
    func setContext(_ context: ModelContext) { self.context = context }

    func heroMessage(completedCount: Int, total: Int) -> String {
        if completedCount == 0 { return "Pick one tiny habit and knock it out. Momentum beats motivation." }
        if completedCount < total { return "Great start! Keep stacking wins to lock in your streak." }
        return "Perfect day. Enjoy the glow, you earned it."
    }

    func loadQuote(showDailyQuotes: Bool) {
        guard showDailyQuotes else {
            quote = ""
            return
        }
        quote = MotivationProvider.dailyQuote()
    }

    func progress(for habit: Habit) -> HabitProgress {
        let target = max(1, habit.dailyTarget)
        guard let entry = todayEntry(for: habit) else {
            return HabitProgress(status: .pending, current: 0, target: target, completion: 0)
        }

        let completion: Double
        switch entry.status {
        case .done:
            completion = 1
        case .skipped:
            completion = 0
        case .pending:
            completion = min(Double(entry.progressValue) / Double(target), 1)
        }

        return HabitProgress(status: entry.status, current: entry.progressValue, target: target, completion: completion)
    }

    func toggleDone(for habit: Habit) {
        guard let entry = todayEntry(for: habit) else { return }
        let wasDone = entry.status == .done
        entry.status = wasDone ? .pending : .done
        if entry.status == .done {
            entry.progressValue = max(entry.progressValue, max(1, habit.dailyTarget))
        } else if wasDone {
            entry.progressValue = 0
        }
        persist()
    }

    func incrementProgress(for habit: Habit) {
        let target = max(1, habit.dailyTarget)
        guard let entry = todayEntry(for: habit) else { return }
        let next = min(entry.progressValue + max(1, target / 4), target)
        entry.progressValue = next
        entry.status = next >= target ? .done : .pending
        persist()
    }
    
    func resetProgress(for habit: Habit) {
        guard let entry = todayEntry(for: habit) else { return }
        entry.progressValue = 0
        entry.status = .pending
        persist()
    }

    private func todayEntry(for habit: Habit) -> HabitEntry? {
        guard let context else { return nil }
        let calendar = Calendar.current
        let habitID = habit.id
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)

        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in
                entry.habit?.id == habitID &&
                entry.date >= start &&
                entry.date < end
            },
            sortBy: [SortDescriptor(\HabitEntry.date, order: .reverse)]
        )
        if let fetched = try? context.fetch(descriptor).first {
            return fetched
        }
        let newEntry = HabitEntry(date: Date(), status: .pending, habit: habit, progressValue: 0)
        context.insert(newEntry)
        persist()
        return newEntry
    }

    private func persist() {
        guard let context, context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            errorMessage = "Could not save changes. Please try again."
            print("FocusViewModel save error: \(error)")
        }
    }
}
