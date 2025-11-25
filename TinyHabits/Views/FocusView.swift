import SwiftUI
import SwiftData

struct FocusView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("profile_name") private var profileName: String = ""
    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue
    @AppStorage("motivation_dailyQuotes") private var showDailyQuotes: Bool = true
    @AppStorage("motivation_haptics") private var enableHaptics: Bool = true

    let habits: [Habit]

    @StateObject private var viewModel = FocusViewModel()

    private var accentColor: Color { AccentTheme(rawValue: accentRaw)?.color ?? .blue }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error)
                    }

                    heroCard

                    if habits.isEmpty {
                        EmptyStateView(accentColor: accentColor)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your focus today")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            ForEach(displayedHabits) { habit in
                                let snapshot = viewModel.progress(for: habit)
                                NavigationLink {
                                    HabitDetailView(habit: habit)
                                } label: {
                                    HabitCard(
                                        habit: habit,
                                        progress: snapshot.completion,
                                        subtitle: snapshot.status == .done ? "Crushed for today." : "Daily target: \(snapshot.target)",
                                        primaryLabel: snapshot.status == .done ? "Revert done" : "Mark done",
                                        onPrimary: { handlePrimary(for: habit, snapshot: snapshot) },
                                        onSecondary: snapshot.status == .done ? nil : { incrementProgress(for: habit) }
                                    )
                                }
                                .buttonStyle(.plain)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Focus")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .onAppear {
            viewModel.setContext(context)
            viewModel.loadQuote(showDailyQuotes: showDailyQuotes)
        }
    }

    private var displayedHabits: [Habit] {
        var seenNames = Set<String>()
        var output: [Habit] = []
        for habit in habits {
            let key = habit.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !seenNames.contains(key) {
                seenNames.insert(key)
                output.append(habit)
            }
            if output.count == 3 { break }
        }
        return output
    }

    private var heroCard: some View {
        HeroHeader(
            title: greetingTitle,
            subtitle: viewModel.heroMessage(completedCount: completedCount, total: displayedHabits.count),
            accent: accentColor,
            quote: nil,
            imageName: AssetNames.onboardingHero
        )
    }

    private var greetingTitle: String {
        profileName.isEmpty ? "Welcome back" : "You got this, \(profileName)"
    }

    private var completedCount: Int {
        habits.filter { viewModel.progress(for: $0).status == .done }.count
    }

    private var momentumText: String {
        let percent = Int(progressRatio * 100)
        return "\(percent)%"
    }

    private var progressRatio: Double {
        guard !displayedHabits.isEmpty else { return 0 }
        let total = displayedHabits.reduce(0.0) { partial, habit in
            partial + viewModel.progress(for: habit).completion
        }
        return total / Double(displayedHabits.count)
    }

    private var nextPendingHabit: Habit? {
        displayedHabits.first { viewModel.progress(for: $0).status != .done }
    }

    private func toggleDone(for habit: Habit) {
        viewModel.toggleDone(for: habit)
        if enableHaptics { HapticManager.shared.play(.celebrate) }
    }

    private func resetProgress(for habit: Habit) {
        viewModel.resetProgress(for: habit)
        if enableHaptics { HapticManager.shared.play(.soft) }
    }

    private func handlePrimary(for habit: Habit, snapshot: HabitProgress) {
        if snapshot.status == .done {
            resetProgress(for: habit)
        } else {
            toggleDone(for: habit)
        }
    }

    private func incrementProgress(for habit: Habit) {
        viewModel.incrementProgress(for: habit)
        if enableHaptics { HapticManager.shared.play(.light) }
    }
}
