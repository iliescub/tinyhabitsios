import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: Habit.activeHabitsPredicate, sort: \Habit.order, order: .forward)
    private var habits: [Habit]
    @EnvironmentObject private var swipeGuard: SwipeGuard
    @State private var themeCardFrame: CGRect = .zero

    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @AppStorage("profile_name") private var storedName: String = ""
    @AppStorage("profile_age") private var storedAge: Int = 30
    @AppStorage("profile_heightCm") private var storedHeightCm: Int = 170
    @AppStorage("profile_weightKg") private var storedWeightKg: Int = 70
    @AppStorage("motivation_dailyQuotes") private var showDailyQuotes: Bool = true
    @AppStorage("motivation_haptics") private var enableHaptics: Bool = true

    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingResetConfirmation = false

    private var accent: Color { AccentTheme(rawValue: accentRaw)?.color ?? .blue }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error)
                    }
                    hero
                    ThemeView()
                    HabitsView()
                        .environmentObject(viewModel)
                    motivationCard
                    resetCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Settings")
        }
        .onAppear {
            viewModel.setContext(context)
            viewModel.hasCompletedOnboarding = hasCompletedOnboarding
        }
        .onDisappear {
            swipeGuard.blockedRegions = []
        }
    }

    // MARK: Sections

    private var hero: some View {
        HeroHeader(
            title: "Tune your experience",
            subtitle: "Keep themes and habits aligned so achievement feels effortless.",
            accent: accent,
            quote: nil,
            imageName: AssetNames.settingsHero
        )
    }

    private func updateThemeCardFrame(_ frame: CGRect) {
        themeCardFrame = frame
        swipeGuard.blockedRegions = [frame]
    }

    private var motivationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Motivation")
                .font(.headline)
            Toggle("Daily quote on launch", isOn: $showDailyQuotes)
            Toggle("Celebration haptics", isOn: $enableHaptics)
            Text("Tiny nudges keep momentum high without overwhelming you.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(DesignTokens.cardBackground())
    }

    private var resetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reset")
                .font(.headline)
            Text("Clears all habits, reminders, and profile data, then reopens onboarding.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                Label("Reset TinyHabits", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
        }
        .padding()
        .background(DesignTokens.cardBackground())
        .alert("Reset TinyHabits?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                var profile = ProfileState(
                    name: storedName,
                    age: storedAge,
                    heightCm: storedHeightCm,
                    weightKg: storedWeightKg,
                    accentRaw: accentRaw
                )
                viewModel.resetAll(profile: &profile)
                storedName = profile.name
                storedAge = profile.age
                storedHeightCm = profile.heightCm
                storedWeightKg = profile.weightKg
                accentRaw = profile.accentRaw
                showDailyQuotes = false
                enableHaptics = true
                hasCompletedOnboarding = viewModel.hasCompletedOnboarding
            }
        } message: {
            Text("This removes all saved data and returns you to the onboarding experience.")
        }
    }

    // MARK: Helpers

    private func isCuratedName(_ name: String) -> Bool {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Habit.curatedTemplates.contains { $0.name.lowercased() == target }
    }

    private func isHabitExisting(name: String) -> Bool {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.activeHabits(using: habits).contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target }
    }
}
