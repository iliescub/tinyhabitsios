import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [HabitEntry]

    let habits: [Habit]

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    init(habits: [Habit]) {
        self.habits = habits
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today

        _entries = Query(filter: #Predicate<HabitEntry> { entry in
            entry.date >= today && entry.date < tomorrow
        })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if habits.isEmpty {
                    Text("Add habits in Settings to get started.")
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ForEach(habits) { habit in
                        HabitCardView(
                            habit: habit,
                            entry: entry(for: habit, on: today),
                            onStatusChange: { status in
                                updateStatus(habit: habit, status: status)
                            }
                        )
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Today")
        }
    }

    private func entry(for habit: Habit, on date: Date) -> HabitEntry? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return entries.first(where: { $0.habit.id == habit.id })
        }

        return entries.first { entry in
            entry.habit.id == habit.id &&
            entry.date >= start &&
            entry.date < end
        }
    }

    private func updateStatus(habit: Habit, status: HabitStatus) {
        let current = entry(for: habit, on: today)

        switch status {
        case .pending:
            if let existing = current {
                context.delete(existing)
            }
        case .done, .skipped:
            if let existing = current {
                existing.status = status
            } else {
                let newEntry = HabitEntry(date: today, status: status, habit: habit)
                context.insert(newEntry)
            }
        }
        try? context.save()
    }
}
