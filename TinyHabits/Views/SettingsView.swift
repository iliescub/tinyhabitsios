import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.order, order: .forward) private var habits: [Habit]

    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @AppStorage("profile_name") private var storedName: String = ""
    @AppStorage("profile_age") private var storedAge: Int = 30
    @AppStorage("profile_heightCm") private var storedHeightCm: Int = 170
    @AppStorage("profile_weightKg") private var storedWeightKg: Int = 70
    @AppStorage("motivation_dailyQuotes") private var showDailyQuotes: Bool = true
    @AppStorage("motivation_haptics") private var enableHaptics: Bool = true

    @State private var newHabitName: String = ""
    @State private var newHabitIcon: String = "sparkles"
    @State private var newHabitColor: AccentTheme = .blue
    @State private var newHabitTarget: Int = 1
    @State private var showingResetConfirmation = false

    private var accent: Color { AccentTheme(rawValue: accentRaw)?.color ?? .blue }
    private var accentGradient: [Color] {
        [
            accent.adjustingBrightness(by: -0.06),
            accent.adjustingBrightness(by: 0.14)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    themeCard
                    habitsCard
                    motivationCard
                    resetCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Settings")
        }
    }

    // MARK: - Sections

    private var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: accent.opacity(0.25), radius: 18, y: 10)

            VStack(alignment: .leading, spacing: 10) {
                Text("Tune your experience")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Keep themes and habits aligned so staying consistent feels effortless.")
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.subheadline)
            }
            .padding(20)
        }
        .frame(height: 140)
    }

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.headline)
            Text("Pick a look that keeps you motivated. Applies across Focus, Stats, and onboarding.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(AccentTheme.allCases) { theme in
                        let gradient = gradientForTheme(theme)
                        Button {
                            accentRaw = theme.rawValue
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(theme.color.opacity(accentRaw == theme.rawValue ? 0.9 : 0.2), lineWidth: 3)
                                    )
                                    .frame(width: 120, height: 70)
                                    .shadow(color: gradient.first?.opacity(0.25) ?? .clear, radius: 10, y: 6)
                                Text(theme.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(cardBackground())
    }

    private var habitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habits")
                .font(.headline)
            Text("Choose up to 3 tiny habits. Mirrors the onboarding picker so your focus stays consistent.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(CuratedHabit.onboardingOptions) { curated in
                    curatedHabitButton(for: curated)
                        .disabled(activeHabits.count >= 3 && !isHabitExisting(name: curated.name))
                }
                ForEach(customHabits) { habit in
                    customHabitRow(for: habit)
                }
            }

            if activeHabits.count > 3 {
                Text("You currently track \(activeHabits.count) habits. TinyHabits works best with 3—remove one to add another.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("Custom habit")
                    .font(.subheadline.weight(.semibold))
                TextField("Name (e.g. Journal 5 min)", text: $newHabitName)
                    .textFieldStyle(.roundedBorder)
                TextField("SF Symbol (e.g. book.fill)", text: $newHabitIcon)
                    .textFieldStyle(.roundedBorder)
                Picker("Accent", selection: $newHabitColor) {
                    ForEach(AccentTheme.allCases) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
                Stepper("Daily target: \(newHabitTarget)", value: $newHabitTarget, in: 1...10000, step: 1)

                Button {
                    addHabit()
                } label: {
                    Label("Add Custom Habit", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(newHabitName.trimmingCharacters(in: .whitespaces).isEmpty || activeHabits.count >= 3)

                if !newHabitName.trimmingCharacters(in: .whitespaces).isEmpty {
                    existingHabitRow(
                        habit: Habit(
                            name: newHabitName.trimmingCharacters(in: .whitespaces),
                            iconSystemName: resolvedSymbolName(newHabitIcon),
                            accentColorKey: newHabitColor.rawValue,
                            order: 0,
                            dailyTarget: newHabitTarget
                        )
                    )
                    .opacity(0.7)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Your habits")
                    .font(.subheadline.weight(.semibold))
                ForEach(activeHabits) { habit in
                    existingHabitRow(habit: habit)
                }
                if activeHabits.isEmpty {
                    Text("No habits yet. Add or pick a curated one above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(cardBackground())
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
        .background(cardBackground())
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
        .background(cardBackground())
        .alert("Reset TinyHabits?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetAppData()
            }
        } message: {
            Text("This removes all saved data and returns you to the onboarding experience.")
        }
    }

    // MARK: - Helpers

    private func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
    }

    private func gradientForTheme(_ theme: AccentTheme) -> [Color] {
        let base = theme.color
        let complement = base.complementary
        return [
            complement.adjustingBrightness(by: -0.08),
            complement.adjustingBrightness(by: 0.12)
        ]
    }

    private func curatedHabitButton(for curated: CuratedHabit) -> some View {
        let isSelected = isHabitExisting(name: curated.name)
        return Button {
            if isSelected {
                if let habit = habits.first(where: { $0.name.caseInsensitiveCompare(curated.name) == .orderedSame }) {
                    deleteHabit(habit)
                }
            } else {
                addCuratedHabit(curated)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? curated.color.color : Color.secondary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: curated.icon)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(curated.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(isSelected ? "Added" : "Tap to include")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(curated.color.color)
                        )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? curated.color.color.opacity(0.15) : Color(.systemBackground))
                    .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.05), radius: isSelected ? 10 : 4, y: isSelected ? 6 : 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func addHabit() {
        guard refreshedActiveHabits().count < 3 else { return }

        let sanitizedName = newHabitName.trimmingCharacters(in: .whitespaces)
        guard !sanitizedName.isEmpty else { return }
        let sanitizedIcon = resolvedSymbolName(newHabitIcon)

        let habit = Habit(
            name: sanitizedName,
            iconSystemName: sanitizedIcon,
            accentColorKey: newHabitColor.rawValue,
            order: refreshedActiveHabits().count,
            dailyTarget: newHabitTarget
        )
        context.insert(habit)
//        saveContext()

        newHabitName = ""
        newHabitIcon = "sparkles"
        newHabitColor = .blue
        newHabitTarget = 1
    }

    private func addCuratedHabit(_ curated: CuratedHabit) {
        guard refreshedActiveHabits().count < 3, !isHabitExisting(name: curated.name) else { return }
        let model = Habit(
            name: curated.name,
            iconSystemName: curated.icon,
            accentColorKey: curated.color.rawValue,
            order: refreshedActiveHabits().count,
            dailyTarget: curated.defaultTarget
        )
        context.insert(model)
//        saveContext()
    }

    private func isHabitExisting(name: String) -> Bool {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return activeHabits.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target }
    }

    private var activeHabits: [Habit] {
        refreshedActiveHabits()
    }

    private var customHabits: [Habit] {
        activeHabits.filter { !isCuratedName($0.name) }
    }

    private func refreshedActiveHabits() -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Habit.order, order: .forward)]
        )
        let fetched = (try? context.fetch(descriptor)) ?? habits
        return fetched.sorted { $0.order < $1.order }
    }

    private func deleteHabit(_ habit: Habit) {
        NotificationManager.shared.cancelReminders(for: habit)
        context.delete(habit)
        normalizeHabitOrder()
//        saveContext()
    }

    private func normalizeHabitOrder() {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Habit.order, order: .forward)]
        )
        if let orderedHabits = try? context.fetch(descriptor) {
            for (index, habit) in orderedHabits.enumerated() {
                habit.order = index
            }
        }
    }

    private func resolvedSymbolName(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "circle" }
        return UIImage(systemName: trimmed) == nil ? "circle" : trimmed
    }

    private func isCuratedName(_ name: String) -> Bool {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return CuratedHabit.onboardingOptions.contains { $0.name.lowercased() == target }
    }

    private func customHabitRow(for habit: Habit) -> some View {
        let accent = (AccentTheme(rawValue: habit.accentColorKey) ?? .blue).color
        return HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                Text("Daily target: \(habit.dailyTarget)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                deleteHabit(habit)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
        )
    }

    private func existingHabitRow(habit: Habit) -> some View {
        let accent = (AccentTheme(rawValue: habit.accentColorKey) ?? .blue).color
        return HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                Text("Daily target: \(habit.dailyTarget)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            NavigationLink {
                HabitDetailView(habit: habit)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            Button(role: .destructive) {
                deleteHabit(habit)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
        )
    }

    private func resetAppData() {
        let entryDescriptor = FetchDescriptor<HabitEntry>()
        let habitDescriptor = FetchDescriptor<Habit>()

        let entries = (try? context.fetch(entryDescriptor)) ?? []
        for entry in entries {
            context.delete(entry)
        }
//        saveContext()

        let allHabits = (try? context.fetch(habitDescriptor)) ?? []
        for habit in allHabits {
            NotificationManager.shared.cancelReminders(for: habit)
            context.delete(habit)
        }
//        saveContext()

        storedName = ""
        storedAge = 30
        storedHeightCm = 170
        storedWeightKg = 70
        accentRaw = AccentTheme.blue.rawValue
        hasCompletedOnboarding = false
        newHabitName = ""
        newHabitIcon = "sparkles"
        newHabitColor = .blue
    }

//    private func saveContext() {
//        guard context.hasChanges else { return }
//        do {
//            try context.save()
//        } catch {
//            print("SettingsView save error: \(error)")
//        }
//    }
}
