import Foundation
import Combine
import SwiftData

@MainActor
final class StatsViewModel: ObservableObject {
    private var context: ModelContext?

    @Published var weekStats: [DayStat] = []
    @Published var currentStreak: Int = 0
    @Published var bestDayTitle: String = "—"
    @Published var bestDayDetail: String = "Complete a habit to unlock insights."
    @Published var weeklyCompletionPercentString: String = "0%"
    @Published var activeHabits: [Habit] = []

    func setContext(_ context: ModelContext) {
        self.context = context
    }

    func refresh(habits: [Habit], entries: [HabitEntry]) {
        self.activeHabits = habits
        computeStats(habits: habits, entries: entries)
    }

    private func computeStats(habits: [Habit], entries: [HabitEntry]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).map { offset in
            calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        }.reversed()

        var stats: [DayStat] = []

        for day in days {
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

            let entriesForDay = entries.filter { entry in
                guard let habit = entry.habit else { return false }
                return entry.date >= dayStart && entry.date < dayEnd && !habit.isArchived
            }

            let done = entriesForDay.filter { $0.status == .done }.count

            let habitsOnDay: Set<UUID> = Set(entriesForDay.compactMap { $0.habit?.id })
            let totalHabits = habitsOnDay.isEmpty ? habits.count : habitsOnDay.count

            let percent = totalHabits == 0 ? 0 : Double(done) / Double(totalHabits)
            stats.append(DayStat(date: day, done: done, total: totalHabits, percent: percent))
        }

        weekStats = stats
        weeklyCompletionPercentString = "\(Int((stats.reduce(0) { $0 + $1.percent } / Double(stats.count)) * 100))%"
        currentStreak = computeStreak(stats: stats)
        updateBestDay(stats: stats)
    }

    private func computeStreak(stats: [DayStat]) -> Int {
        let reversed = stats.reversed()
        var streak = 0
        for stat in reversed {
            if stat.done > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func updateBestDay(stats: [DayStat]) {
        guard let best = stats.max(by: { $0.percent < $1.percent }), best.percent > 0 else {
            bestDayTitle = "—"
            bestDayDetail = "Complete a habit to unlock insights."
            return
        }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        bestDayTitle = formatter.string(from: best.date)
        bestDayDetail = "\(Int(best.percent * 100))% completion on \(bestDayTitle)."
    }
}

struct DayStat {
    let date: Date
    let done: Int
    let total: Int
    let percent: Double
}
