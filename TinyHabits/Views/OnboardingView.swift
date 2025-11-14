import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @State private var selectedHabits: Set<CuratedHabit> = []
    @State private var customHabitName: String = ""

    private let curated: [CuratedHabit] = [
        CuratedHabit(name: "Drink Water", icon: "drop.fill", color: .blue),
        CuratedHabit(name: "Stretch", icon: "figure.cooldown", color: .green),
        CuratedHabit(name: "Read 10 Minutes", icon: "book.fill", color: .orange),
        CuratedHabit(name: "Walk", icon: "figure.walk", color: .green),
        CuratedHabit(name: "Meditate", icon: "sparkles", color: .blue)
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TinyHabits")
                        .font(.largeTitle.bold())
                    Text("Pick up to three tiny habits to focus on every day.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Curated Habits")
                        .font(.headline)

                    ForEach(curated) { habit in
                        Button {
                            toggleSelection(habit)
                        } label: {
                            HStack {
                                Image(systemName: habit.icon)
                                Text(habit.name)
                                Spacer()
                                if selectedHabits.contains(habit) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Or create your own")
                        .font(.headline)
                    TextField("Custom habit (optional)", text: $customHabitName)
                        .textFieldStyle(.roundedBorder)
                }

                Spacer()

                Button {
                    completeOnboarding()
                } label: {
                    Text("Start Tracking")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(selectedHabits.isEmpty && customHabitName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
    }

    private func toggleSelection(_ habit: CuratedHabit) {
        if selectedHabits.contains(habit) {
            selectedHabits.remove(habit)
        } else if selectedHabits.count < 3 {
            selectedHabits.insert(habit)
        }
    }

    private func completeOnboarding() {
        var index = 0

        for habit in selectedHabits.prefix(3) {
            let model = Habit(
                name: habit.name,
                iconSystemName: habit.icon,
                accentColorKey: habit.color.rawValue,
                order: index
            )
            context.insert(model)
            index += 1
        }

        if !customHabitName.trimmingCharacters(in: .whitespaces).isEmpty && index < 3 {
            let model = Habit(
                name: customHabitName.trimmingCharacters(in: .whitespaces),
                iconSystemName: "circle",
                accentColorKey: AccentTheme.blue.rawValue,
                order: index
            )
            context.insert(model)
        }

        context.saveIfNeeded()
        hasCompletedOnboarding = true
    }
}

struct CuratedHabit: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let color: AccentTheme
}
