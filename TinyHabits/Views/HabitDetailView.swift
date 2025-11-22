import SwiftUI
import SwiftData

struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue
    @AppStorage("motivation_haptics") private var enableHaptics: Bool = true

    let habit: Habit

    private var accent: Color {
        AccentTheme(rawValue: habit.accentColorKey)?.color ?? AccentTheme(rawValue: accentRaw)?.color ?? .blue
    }

    @State private var reminderTime: Date = Date()
    @State private var reminderEnabled: Bool = false
    @State private var showingPermissionAlert = false

    private var entries: [HabitEntry] {
        habit.entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                streakCard

                recentHistory

                reminderCard

                detailMetrics
            }
            .padding()
        }
        .onAppear {
            seedReminderState()
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: habit.iconSystemName)
                    .font(.title2)
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                Text("Daily target: \(habit.dailyTarget)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
        )
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep the chain")
                .font(.headline)

            HStack(spacing: 16) {
                streakPill(title: "Current", value: "\(currentStreak)d")
                streakPill(title: "Best", value: "\(bestStreak)d")
                streakPill(title: "Last 7d", value: "\(last7CompletionPercent)%")
            }

            ProgressView(value: Double(last7CompletionPercent), total: 100)
                .tint(accent)
                .animation(.spring(response: 0.6, dampingFraction: 0.85), value: last7CompletionPercent)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
        )
    }

    private var recentHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent days")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(last7Days, id: \.self) { day in
                    let status = status(on: day)
                    VStack(spacing: 6) {
                        Circle()
                            .fill(color(for: status))
                            .frame(width: 14, height: 14)
                        Text(shortLabel(for: day))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
        )
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminders")
                .font(.headline)

            Toggle(isOn: $reminderEnabled) {
                Text("Daily reminder")
            }
            .onChange(of: reminderEnabled) { _, newValue in
                handleReminderToggle(enabled: newValue)
            }

            if reminderEnabled {
                DatePicker(
                    "Time",
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: reminderTime) { _, _ in
                    saveReminder()
                }
            }

            Text(reminderEnabled ? "We’ll nudge you every day at the selected time." : "Turn on to get a gentle nudge.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
        )
        .alert("Notifications Off", isPresented: $showingPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable notifications in Settings to schedule reminders.")
        }
    }

    private var detailMetrics: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                Text("Total completions: \(totalDone)")
                Text("Skipped days: \(totalSkipped)")
                Text("Created: \(formattedDate(habit.createdAt))")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
        )
    }

    // MARK: - Calculations

    private var last7Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
    }

    private func status(on date: Date) -> HabitStatus {
        let calendar = Calendar.current
        return entries.first { calendar.isDate($0.date, inSameDayAs: date) }?.status ?? .pending
    }

    private func color(for status: HabitStatus) -> Color {
        switch status {
        case .done: return .green
        case .skipped: return .orange
        case .pending: return .gray
        }
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        for day in last7Days.reversed() {
            if status(on: day) == .done {
                streak += 1
            } else if !calendar.isDateInToday(day) {
                break
            }
        }
        return streak
    }

    private var bestStreak: Int {
        let calendar = Calendar.current
        var best = 0
        var current = 0
        let ordered = entries.sorted { $0.date < $1.date }
        for entry in ordered {
            if entry.status == .done {
                current += 1
                best = max(best, current)
            } else {
                // reset when skipped/pending
                if !calendar.isDateInToday(entry.date) {
                    current = 0
                }
            }
        }
        return max(best, current)
    }

    private var last7CompletionPercent: Int {
        let doneCount = last7Days.filter { status(on: $0) == .done }.count
        let percent = (Double(doneCount) / Double(max(1, last7Days.count))) * 100
        return Int(percent.rounded())
    }

    private var totalDone: Int {
        entries.filter { $0.status == .done }.count
    }

    private var totalSkipped: Int {
        entries.filter { $0.status == .skipped }.count
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return formatter.string(from: date)
    }

    private func shortLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("E")
        return formatter.string(from: date).prefix(1).uppercased()
    }

    private func streakPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(accent)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Reminders

    private func handleReminderToggle(enabled: Bool) {
        if enabled {
            NotificationManager.shared.ensureAuthorization { granted in
                DispatchQueue.main.async {
                    if granted {
                        saveReminder()
                    } else {
                        reminderEnabled = false
                        showingPermissionAlert = true
                    }
                }
            }
        } else {
            habit.reminders.removeAll()
            NotificationManager.shared.cancelReminders(for: habit)
            try? context.save()
        }
    }

    private func saveReminder() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        guard let hour = components.hour, let minute = components.minute else { return }
        habit.reminders = [HabitReminder(hour: hour, minute: minute)]
        do {
            try context.save()
        } catch {
            reminderEnabled = false
            showingPermissionAlert = true
            return
        }
        NotificationManager.shared.ensureAuthorization { granted in
            DispatchQueue.main.async {
                if granted {
                    NotificationManager.shared.scheduleReminders(for: habit)
                    if enableHaptics {
                        HapticManager.shared.play(.success)
                    }
                } else {
                    reminderEnabled = false
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func seedReminderState() {
        if let first = habit.reminders.first {
            reminderEnabled = true
            var components = DateComponents()
            components.hour = first.hour
            components.minute = first.minute
            reminderTime = Calendar.current.date(from: components) ?? Date()
        } else {
            reminderEnabled = false
            reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        }
    }
}
