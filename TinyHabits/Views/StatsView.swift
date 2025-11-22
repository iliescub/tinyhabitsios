//
//  StatsView.swift
//  TinyHabits
//
//  Created by Bogdan Iliescu on 20.11.2025.
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue
    @AppStorage("profile_name") private var profileName: String = ""

    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.order, order: .forward)
    private var habits: [Habit]

    @Query(sort: \HabitEntry.date, order: .reverse)
    private var entries: [HabitEntry]

    private var accent: Color { AccentTheme(rawValue: accentRaw)?.color ?? .blue }
    private var accentGradient: [Color] {
        [
            accent.adjustingBrightness(by: -0.06),
            accent.adjustingBrightness(by: 0.12)
        ]
    }
    private var activeHabits: [Habit] { habits }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard

                    weeklyChart

                    metricsGrid

                    highlights
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: accent.opacity(0.25), radius: 18, y: 10)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("Weekly momentum")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                    Image(systemName: "sparkles")
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text(heroTitle)
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text(heroSubtitle)
                    .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: 16) {
                    heroChip(title: "Completion", value: weeklyCompletionPercentString)
                    heroChip(title: "Streak", value: "\(currentStreak)d")
                    heroChip(title: "Habits", value: "\(activeHabits.count)")
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 120, height: 120)
                .offset(x: 18, y: 18)
        }
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This week")
                        .font(.headline)
                    Text("Celebrate each win. Small bars get taller fast.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(weeklyCompletionPercentString)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(weekStats, id: \.date) { stat in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 26, height: 120)

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LinearGradient(colors: [accent.opacity(0.9), accent.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 26, height: max(10, 120 * stat.percent))
                                .shadow(color: accent.opacity(0.15), radius: 6, y: 3)
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: stat.percent)

                        Text(shortDayLabel(for: stat.date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 6)
        )
    }

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Momentum metrics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCard(title: "Current streak", value: "\(currentStreak) days", detail: "Consecutive days with any habit done.")
                metricCard(title: "Best day", value: bestDayTitle, detail: bestDayDetail)
                metricCard(title: "Average completion", value: weeklyCompletionPercentString, detail: "Across all habits this week.")
                metricCard(title: "Habits tracked", value: "\(activeHabits.count)", detail: "Keep it tiny. 3 is the sweet spot.")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 6)
        )
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Highlights")
                .font(.headline)

            highlightRow(
                systemImage: "flame",
                title: "Keep the flame",
                message: currentStreak > 0 ? "On a \(currentStreak)-day run. Don’t break the chain." : "Light your streak with one quick win today.",
                tint: .orange
            )

            highlightRow(
                systemImage: "trophy",
                title: "Best of the week",
                message: bestDayDetail,
                tint: .yellow
            )

            highlightRow(
                systemImage: "arrow.triangle.2.circlepath",
                title: "Consistency",
                message: "Aiming for 70%+ weekly completion keeps progress sustainable.",
                tint: .teal
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 6)
        )
    }

    // MARK: - Data helpers

    private var weekStats: [DayStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).map { offset in
            calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        }.reversed()

        return days.map { day in
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

            let entriesForDay = entries.filter {
                $0.date >= dayStart && $0.date < dayEnd && !$0.habit.isArchived
            }

            let done = entriesForDay.filter { $0.status == .done }.count

            // If there are no entries that day (e.g., habit added mid-week), fall back to current active habit count.
            let habitsOnDay: Set<UUID> = Set(entriesForDay.map { $0.habit.id })
            let totalHabits = habitsOnDay.isEmpty ? activeHabits.count : habitsOnDay.count

            let percent = totalHabits == 0 ? 0 : Double(done) / Double(totalHabits)
            return DayStat(date: day, done: done, total: totalHabits, percent: percent)
        }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        for stat in weekStats.reversed() {
            if stat.done > 0 {
                streak += 1
            } else {
                // Stop counting if we hit a missed day before today.
                if !calendar.isDateInToday(stat.date) {
                    break
                }
            }
        }
        return streak
    }

    private var weeklyCompletionPercent: Double {
        guard !weekStats.isEmpty else { return 0 }
        let total = weekStats.reduce(0.0) { $0 + $1.percent }
        return total / Double(weekStats.count)
    }

    private var weeklyCompletionPercentString: String {
        let value = Int(weeklyCompletionPercent * 100)
        return "\(value)%"
    }

    private var bestDay: DayStat? {
        weekStats.max { $0.percent < $1.percent }
    }

    private var bestDayTitle: String {
        guard let best = bestDay else { return "—" }
        return longDayLabel(for: best.date)
    }

    private var bestDayDetail: String {
        guard let best = bestDay else { return "Complete a habit to unlock insights." }
        let value = Int(best.percent * 100)
        return "\(value)% completion on \(longDayLabel(for: best.date))."
    }

    // MARK: - Small views

    private func heroChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(accent)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func highlightRow(systemImage: String, title: String, message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func shortDayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("E")
        return formatter.string(from: date).prefix(1).uppercased()
    }

    private func longDayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    private var heroTitle: String {
        if weeklyCompletionPercent >= 0.8 {
            return "Streak mode"
        } else if weeklyCompletionPercent >= 0.5 {
            return "Momentum building"
        } else {
            return profileName.isEmpty ? "Let’s kick this off" : "Let’s go, \(profileName)"
        }
    }

    private var heroSubtitle: String {
        switch currentStreak {
        case 0:
            return "One small win today lights the path."
        case 1...3:
            return "Keep it tiny and keep it daily."
        default:
            return "Protect your streak—your future self will thank you."
        }
    }
}

private struct DayStat {
    let date: Date
    let done: Int
    let total: Int
    let percent: Double
}
