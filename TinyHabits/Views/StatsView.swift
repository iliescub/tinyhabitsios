import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue
    @AppStorage("profile_name") private var profileName: String = ""

    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.order, order: .forward)
    private var habits: [Habit]

    @Query(sort: \HabitEntry.date, order: .reverse)
    private var entries: [HabitEntry]

    @StateObject private var viewModel = StatsViewModel()

    private var accent: Color { AccentTheme(rawValue: accentRaw)?.color ?? .blue }
    private var accentGradient: [Color] {
        [
            accent.adjustingBrightness(by: -0.06),
            accent.adjustingBrightness(by: 0.12)
        ]
    }

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
        .onAppear {
            viewModel.setContext(context)
            viewModel.refresh(habits: habits, entries: entries)
        }
    }


    private var heroCard: some View {
        HeroHeader(
            title: "Weekly momentum",
            subtitle: "\(heroTitle) · \(heroSubtitle)",
            accent: accent,
            quote: nil,
            imageName: AssetNames.onboardingHero
        )
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
                Text(viewModel.weeklyCompletionPercentString)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(viewModel.weekStats, id: \.date) { stat in
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
                metricCard(title: "Current streak", value: "\(viewModel.currentStreak) days", detail: "Consecutive days with any habit done.")
                metricCard(title: "Best day", value: viewModel.bestDayTitle, detail: viewModel.bestDayDetail)
                metricCard(title: "Average completion", value: viewModel.weeklyCompletionPercentString, detail: "Across all habits this week.")
                metricCard(title: "Habits tracked", value: "\(viewModel.activeHabits.count)", detail: "Keep it tiny. 3 is the sweet spot.")
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
                message: viewModel.currentStreak > 0 ? "On a \(viewModel.currentStreak)-day run. Don’t break the chain." : "Light your streak with one quick win today.",
                tint: .orange
            )

            highlightRow(
                systemImage: "trophy",
                title: "Best of the week",
                message: viewModel.bestDayDetail,
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

    private var heroTitle: String {
        if viewModel.weeklyCompletionPercentString.trimmingCharacters(in: .whitespacesAndNewlines) == "100%" {
            return "Streak mode"
        } else if viewModel.currentStreak >= 3 {
            return "Momentum building"
        } else {
            return profileName.isEmpty ? "Let’s kick this off" : "Let’s go, \(profileName)"
        }
    }

    private var heroSubtitle: String {
        switch viewModel.currentStreak {
        case 0:
            return "One small win today lights the path."
        case 1...3:
            return "Keep it tiny and keep it daily."
        default:
            return "Protect your streak—your future self will thank you."
        }
    }
}
