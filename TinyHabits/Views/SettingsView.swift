import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order, order: .forward) private var habits: [Habit]

    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue

    @State private var newHabitName: String = ""
    @State private var newHabitIcon: String = "drop.fill"
    @State private var newHabitColor: AccentTheme = .blue

    var body: some View {
        NavigationStack {
            Form {
                Section("Habits") {
                    if habits.count < 3 {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("New habit", text: $newHabitName)
                            TextField("SF Symbol (e.g. book.fill)", text: $newHabitIcon)
                            Picker("Accent", selection: $newHabitColor) {
                                ForEach(AccentTheme.allCases) { theme in
                                    Text(theme.rawValue.capitalized)
                                        .tag(theme)
                                }
                            }

                            Button("Add Habit") {
                                addHabit()
                            }
                            .disabled(newHabitName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Text("You're limited to three core habits to keep things tiny and focused.")
                    }

                    ForEach(habits) { habit in
                        HStack {
                            Text(habit.name)
                            Spacer()
                            Text(habit.iconSystemName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: deleteHabits)
                }

                Section("Reminders") {
                    ForEach(habits) { habit in
                        NavigationLink(habit.name) {
                            HabitReminderSettingsView(habit: habit)
                        }
                    }
                }

                Section("Theme") {
                    Picker("Accent Color", selection: $accentRaw) {
                        ForEach(AccentTheme.allCases) { theme in
                            Text(theme.rawValue.capitalized)
                                .tag(theme.rawValue)
                        }
                    }
                }

                Section("Pro") {
                    ProSectionView()
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func addHabit() {
        guard habits.count < 3 else { return }

        let habit = Habit(
            name: newHabitName.trimmingCharacters(in: .whitespaces),
            iconSystemName: newHabitIcon.isEmpty ? "circle" : newHabitIcon,
            accentColorKey: newHabitColor.rawValue,
            order: habits.count
        )
        context.insert(habit)
        context.saveIfNeeded()

        newHabitName = ""
        newHabitIcon = "drop.fill"
        newHabitColor = .blue
    }

    private func deleteHabits(at offsets: IndexSet) {
        for index in offsets {
            let habit = habits[index]
            context.delete(habit)
        }
        context.saveIfNeeded()
    }
}

struct HabitReminderSettingsView: View {
    @Environment(\.modelContext) private var context
    @Bindable var habit: Habit

    @State private var hasReminder: Bool = false
    @State private var reminderTime: Date = Date()

    var body: some View {
        Form {
            Toggle("Enable Reminder", isOn: $hasReminder.animation())

            if hasReminder {
                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
            }
        }
        .navigationTitle(habit.name)
        .onAppear {
            if let components = habit.reminderComponents(),
               let date = Calendar.current.date(from: components) {
                hasReminder = true
                reminderTime = date
            } else {
                hasReminder = false
            }
        }
        .onDisappear {
            save()
        }
    }

    private func save() {
        if hasReminder {
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            habit.reminderHour = components.hour
            habit.reminderMinute = components.minute
            NotificationManager.shared.scheduleDailyReminder(for: habit)
        } else {
            habit.reminderHour = nil
            habit.reminderMinute = nil
            NotificationManager.shared.cancelReminder(for: habit)
        }
        context.saveIfNeeded()
    }
}

struct ProSectionView: View {
    @StateObject private var store = StoreManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TinyHabits Pro")
                    .font(.headline)
                Text("Support development and unlock future extras.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if store.isProUnlocked {
                Label("Unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Upgrade") {
                    Task {
                        await store.purchasePro()
                    }
                }
            }
        }
    }
}

