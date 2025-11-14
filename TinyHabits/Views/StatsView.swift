import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.createdAt, order: .forward)
    private var habits: [Habit]
    @Query private var entries: [HabitEntry]

    private var calendar: Calendar { Calendar.current }

    private var last7Days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }.reversed()
    }
    init() {}
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if habits.isEmpty {
                        Text("Once you add habits, you'll see your streaks and charts here.")
                            .multilineTextAlignment(.leading)
                            .padding(.top)
                    } else {
                        streakSection
                        weeklyChartSection
                    }
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
    }

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Streaks")
                .font(.headline)

            ForEach(habits) { habit in
                let streak = streakForHabit(habit)
                HStack {
                    Text(habit.name)
                    Spacer()
                    Text("\(streak) day\(streak == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)

            Chart {
                ForEach(last7Days, id: \.self) { day in
                    let total = entriesForDay(day).filter { $0.status == .done }.count
                    BarMark(
                        x: .value("Day", day, unit: .day),
                        y: .value("Completed", total)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .frame(height: 200)
        }
    }

    private func entriesForDay(_ date: Date) -> [HabitEntry] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return entries.filter { $0.date >= start }
        }
        return entries.filter { $0.date >= start && $0.date < end }
    }

    private func streakForHabit(_ habit: Habit) -> Int {
        var streak = 0
        var day = calendar.startOfDay(for: Date())

        while true {
            let entriesForDay = self.entriesForDay(day)
            let status = entriesForDay.first(where: { $0.habit.id == habit.id })?.status ?? .pending
            if status == .done {
                streak += 1
                if let previous = calendar.date(byAdding: .day, value: -1, to: day) {
                    day = previous
                } else {
                    break
                }
            } else {
                break
            }
        }

        return streak
    }
}

