import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.order, order: .forward)
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
            subtitle: "Keep themes and habits aligned so staying consistent feels effortless.",
            accent: accent,
            quote: nil,
            imageName: AssetNames.onboardingHero
        )
    }

//    private var themeCard: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Theme")
//                .font(.headline)
//            Text("Pick a look that keeps you motivated. Applies across Focus, Stats, and onboarding.")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//
//            ScrollView(.horizontal, showsIndicators: false) {
//                HStack(spacing: 14) {
//                    ForEach(AccentTheme.allCases) { theme in
//                        ThemeChip(theme: theme, isSelected: accentRaw == theme.rawValue) {
//                            accentRaw = theme.rawValue
//                        }
//                    }
//                }
//            }
//        }
//        .padding()
//        .background(
//            GeometryReader { geometry in
//                Color.clear
//                .onAppear {
//                    updateThemeCardFrame(geometry.frame(in: .named("MainTabSpace")))
//                }
//                .onChange(of: geometry.frame(in: .named("MainTabSpace"))) { _, frame in
//                    updateThemeCardFrame(frame)
//                }
//            }
//        )
//        .background(DesignTokens.cardBackground())
//    }
//
//    private var habitsCard: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Habits")
//                .font(.headline)
//            Text("Choose up to 3 tiny habits. Mirrors the onboarding picker so your focus stays consistent.")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//
//            VStack(spacing: 12) {
//                ForEach(CuratedHabit.onboardingOptions) { curated in
//                    curatedHabitButton(for: curated)
//                        .disabled(viewModel.activeHabits(using: habits).count >= 3 && !isHabitExisting(name: curated.name))
//                }
//                ForEach(customHabits) { habit in
//                    HabitRow(habit: habit, showDetails: false, onDelete: {
//                        viewModel.deleteHabit(habit)
//                    })
//                }
//            }
//
//            if viewModel.activeHabits(using: habits).count > 3 {
//                Text("You currently track \(viewModel.activeHabits(using: habits).count) habits. TinyHabits works best with 3—remove one to add another.")
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }
//
//            Divider().padding(.vertical, 4)
//
//            VStack(alignment: .leading, spacing: 10) {
//                Text("Custom habit")
//                    .font(.subheadline.weight(.semibold))
//                TextField("Name (e.g. Journal 5 min)", text: $viewModel.newHabitName)
//                    .textFieldStyle(.roundedBorder)
//                TextField("SF Symbol (e.g. book.fill)", text: $viewModel.newHabitIcon)
//                    .textFieldStyle(.roundedBorder)
//                Picker("Accent", selection: $viewModel.newHabitColor) {
//                    ForEach(AccentTheme.allCases) { theme in
//                        Text(theme.rawValue.capitalized).tag(theme)
//                    }
//                }
//                Stepper("Daily target: \(viewModel.newHabitTarget)", value: $viewModel.newHabitTarget, in: 1...10000, step: 1)
//
//                Button {
//                    viewModel.addCustomHabit(currentHabits: habits)
//                } label: {
//                    Label("Add Custom Habit", systemImage: "plus.circle.fill")
//                        .frame(maxWidth: .infinity)
//                }
//                .buttonStyle(.borderedProminent)
//                .tint(accent)
//                .disabled(viewModel.newHabitName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.activeHabits(using: habits).count >= 3)
//            }
//            .padding()
//            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
//
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Your habits")
//                    .font(.subheadline.weight(.semibold))
//                ForEach(viewModel.activeHabits(using: habits)) { habit in
//                    HabitRow(habit: habit, onDelete: { viewModel.deleteHabit(habit) })
//                }
//                if viewModel.activeHabits(using: habits).isEmpty {
//                    Text("No habits yet. Add or pick a curated one above.")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
//            }
//        }
//        .padding()
//        .background(DesignTokens.cardBackground())
//    }

    private func updateThemeCardFrame(_ frame: CGRect) {
        themeCardFrame = frame
        swipeGuard.blockedRegions = [frame]
    }

//    private var customHabits: [Habit] {
//        viewModel.activeHabits(using: habits).filter { !isCuratedName($0.name) }
//    }
//
//    private func curatedHabitButton(for curated: CuratedHabit) -> some View {
//        let isSelected = isHabitExisting(name: curated.name)
//        return Button {
//            if isSelected {
//                if let habit = habits.first(where: { $0.name.caseInsensitiveCompare(curated.name) == .orderedSame }) {
//                    viewModel.deleteHabit(habit)
//                }
//            } else {
//                viewModel.addCurated(curated, currentHabits: habits)
//            }
//        } label: {
//            HStack(spacing: 12) {
//                ZStack {
//                    RoundedRectangle(cornerRadius: 12, style: .continuous)
//                        .fill(isSelected ? curated.color.color : Color.secondary.opacity(0.15))
//                        .frame(width: 48, height: 48)
//                    Image(systemName: curated.icon)
//                        .foregroundStyle(isSelected ? .white : .primary)
//                        .font(.title3)
//                }
//                VStack(alignment: .leading, spacing: 4) {
//                    Text(curated.name)
//                        .font(.headline)
//                        .foregroundStyle(.primary)
//                    Text(isSelected ? "Added" : "Tap to include")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                }
//                Spacer()
//                if isSelected {
//                    Image(systemName: "checkmark.circle.fill")
//                        .foregroundStyle(.white)
//                        .padding(6)
//                        .background(
//                            Circle()
//                                .fill(curated.color.color)
//                        )
//                }
//            }
//            .padding()
//            .background(
//                RoundedRectangle(cornerRadius: 16, style: .continuous)
//                    .fill(isSelected ? curated.color.color.opacity(0.15) : Color(.systemBackground))
//                    .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.05), radius: isSelected ? 10 : 4, y: isSelected ? 6 : 2)
//            )
//        }
//        .buttonStyle(.plain)
//    }

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

    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("SettingsView save error: \(error)")
        }
    }
}
