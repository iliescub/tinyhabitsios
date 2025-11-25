import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var viewModel: SettingsViewModel
    @Query(sort: \Habit.order, order: .forward)
    private var habits: [Habit]

    @AppStorage("accentTheme") private var storedAccentTheme: String = AccentTheme.blue.rawValue

    private let curated: [Habit] = Habit.curatedTemplates
    private var accentTheme: AccentTheme {
        AccentTheme(rawValue: storedAccentTheme) ?? .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Habits")
                .font(.headline)
            Text("Choose up to 3 tiny habits.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(curated) { curated in
                    curatedHabitButton(for: curated)
                        .disabled(viewModel.activeHabits(using: habits).count >= 3 && !isHabitExisting(name: curated.name))
                }
                ForEach(customHabits) { habit in
                    customHabitButton(for: habit)
                        .disabled(viewModel.activeHabits(using: habits).count >= 3 && habit.isArchived)
                }
            }

//            if viewModel.activeHabits(using: habits).count > 3 {
//                Text("You currently track \(viewModel.activeHabits(using: habits).count) habits. TinyHabits works best with 3—remove one to add another.")
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }

            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text("Custom habit")
                    .font(.subheadline.weight(.semibold))
                TextField("Name (e.g. Journal 5 min)", text: $viewModel.newHabitName)
                    .textFieldStyle(.roundedBorder)
                Picker("Icon", selection: $viewModel.newHabitIcon) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Label(icon, systemImage: icon).tag(icon)
                    }
                }
                .pickerStyle(.menu)
                Picker("Accent", selection: $viewModel.newHabitColor) {
                    ForEach(AccentTheme.allCases) { theme in
                        Text(theme.rawValue.capitalized).tag(theme)
                    }
                }
                Stepper("Daily target: \(viewModel.newHabitTarget)", value: $viewModel.newHabitTarget, in: 1...10000, step: 1)

                Button {
                    viewModel.addCustomHabit(currentHabits: habits)
                } label: {
                    Label("Add Custom Habit", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accentTheme.color)
                .disabled(viewModel.newHabitName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.activeHabits(using: habits).count >= 3)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
        }
        .padding()
        .background(DesignTokens.cardBackground())
    }

    private var customHabits: [Habit] {
        habits.filter { !isCuratedName($0.name) }
    }

    private var availableIcons: [String] {
        ["book.fill", "figure.walk", "drop.fill", "sparkles", "heart.fill"]
    }

    private func curatedHabitButton(for curated: Habit) -> some View {
        let accent = (AccentTheme(rawValue: curated.accentColorKey) ?? .blue).color
        let isSelected = isHabitExisting(name: curated.name)
        return Button {
            if isSelected {
                if let habit = habits.first(where: { $0.name.caseInsensitiveCompare(curated.name) == .orderedSame }) {
                    viewModel.deleteHabit(habit)
                }
            } else {
                viewModel.addCurated(curated, currentHabits: habits)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? accent : Color.secondary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: curated.iconSystemName)
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
                                .fill(accent)
                        )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.15) : Color(.systemBackground))
                    .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.05), radius: isSelected ? 10 : 4, y: isSelected ? 6 : 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func customHabitButton(for habit: Habit) -> some View {
        let accent = (AccentTheme(rawValue: habit.accentColorKey) ?? .blue).color
        let isSelected = !habit.isArchived


        return Button {
            if isSelected {
                viewModel.archiveHabit(habit)
            } else {
                viewModel.activateHabit(habit, currentHabits: habits)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? accent.opacity(0.15) : Color.secondary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: habit.iconSystemName)
                        .foregroundStyle(isSelected ? .white : accent)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Daily target: \(habit.dailyTarget)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(accent)
                            )
                    }
                    Button(role: .destructive) {
                        viewModel.deleteHabit(habit)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.15) : Color(.systemBackground))
                    .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.05), radius: isSelected ? 10 : 4, y: isSelected ? 6 : 2)
            )
            .opacity(!isSelected ? 0.6 : 1)
        }
        .buttonStyle(.plain)

    }

    private func isCuratedName(_ name: String) -> Bool {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return curated.contains { $0.name.lowercased() == target }
    }

    private func isHabitExisting(name: String) -> Bool {
        let target = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.activeHabits(using: habits).contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == target }
    }
}

// MARK: - Reusable Cards

struct HabitCard: View {
    let habit: Habit
    let progress: Double
    let subtitle: String
    let primaryLabel: String
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    private var accent: Color {
        (AccentTheme(rawValue: habit.accentColorKey) ?? .blue).color
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: habit.iconSystemName)
                        .font(.headline)
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ProgressRing(progress: progress, accent: accent)
                    .frame(width: 36, height: 36)
            }

            HStack(spacing: 10) {
                Button(action: onPrimary) {
                    Label(primaryLabel, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(accent.opacity(0.9))
                        .clipShape(Capsule(style: .continuous))
                        .shadow(color: accent.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(.plain)

                if let onSecondary {
                    Button(action: onSecondary) {
                        Label("More", systemImage: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemBackground), in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: DesignTokens.shadow, radius: DesignTokens.shadowRadius, y: DesignTokens.shadowY)
        )
    }
}

struct HabitRow: View {
    let habit: Habit
    var showDetails: Bool = true
    var onDelete: (() -> Void)?

    private var accent: Color {
        (AccentTheme(rawValue: habit.accentColorKey) ?? .blue).color
    }

    var body: some View {
        HStack(spacing: 12) {
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
            if showDetails {
                NavigationLink {
                    HabitDetailView(habit: habit)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: DesignTokens.shadow, radius: DesignTokens.shadowRadius, y: DesignTokens.shadowY)
        )
    }
}
