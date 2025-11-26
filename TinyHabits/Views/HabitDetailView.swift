import SwiftUI
import SwiftData
import UIKit

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
//    @State private var stepCount: Int?
//    @State private var heartRate: Double?
//    @State private var sleepHours: Double?
//    @State private var healthError: String?
//    @State private var healthAuthResult: HealthAuthorizationResult?
//    @State private var isRequestInProgress = false
//    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private var entries: [HabitEntry] {
        habit.entries.sorted { $0.date > $1.date }
    }
    
    private var todayEntry: HabitEntry? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return entries.first { $0.date >= start && $0.date < end }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                streakCard

                dailyAchievement

                recentHistory

                reminderCard

//                HealthKitView()

                detailMetrics
            }
            .padding()
        }
        .onAppear {
            seedReminderState()
//            requestHealthData()
        }
//        .onChange(of: scenePhase) { _, phase in
//            if phase == .active {
//                requestHealthData(force: true)
//            }
//        }
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
//                Text("Created: \(formattedDate(habit.createdAt))")
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

//    private var healthSnapshot: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Health snapshot")
//                .font(.headline)
//
//            HStack(spacing: 12) {
//                healthMetric(title: "Steps today", value: stepCountString, detail: "From HealthKit")
//                healthMetric(title: "Heart rate", value: heartRateString, detail: "Latest reading")
//                healthMetric(title: "Sleep", value: sleepString, detail: "Last night")
//            }
//
//            if let message = healthMessageText {
//                Text(message)
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }
//
//            healthActionButton()
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 18, style: .continuous)
//                .fill(Color(.systemBackground))
//                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
//        )
//    }

    private var dailyAchievement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's progress")
                .font(.headline)
            let target = max(1, habit.dailyTarget)
            let current = todayEntry?.progressValue ?? 0
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Achieved: \(current)")
                    Spacer()
                    Text("Target: \(target)")
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(todayEntry?.progressValue ?? 0) },
                        set: { newValue in
                            updateTodayProgress(to: Int(newValue.rounded()), target: target)
                        }
                    ),
                    in: 0...Double(target),
                    step: 1
                )
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
        )
    }

    private func updateTodayProgress(to newValue: Int, target: Int) {
        let clamped = max(0, min(target, newValue))
        let entry: HabitEntry
        if let existing = todayEntry {
            entry = existing
        } else {
            let created = HabitEntry(date: Date(), status: .pending, habit: habit, progressValue: 0)
            context.insert(created)
            entry = created
        }
        entry.progressValue = clamped
        entry.status = clamped >= target ? .done : .pending
        if enableHaptics { HapticManager.shared.play(.light) }
        try? context.save()
    }

//    private func healthMetric(title: String, value: String, detail: String) -> some View {
//        VStack(alignment: .leading, spacing: 4) {
//            Text(title)
//                .font(.caption2.weight(.semibold))
//                .foregroundStyle(.secondary)
//            Text(value)
//                .font(.title3.bold())
//            Text(detail)
//                .font(.caption)
//                .foregroundStyle(.secondary)
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 14, style: .continuous)
//                .fill(Color(.secondarySystemBackground))
//        )
//    }
//
//    private var stepCountString: String {
//        if let steps = stepCount {
//            return "\(steps)"
//        }
//        return "—"
//    }
//
//    private var heartRateString: String {
//        if let bpm = heartRate {
//            return String(format: "%.0f bpm", bpm)
//        }
//        return "—"
//    }
//    
//    private var sleepString: String {
//        if let hours = sleepHours {
//            return String(format: "%.1f h", hours)
//        }
//        return "—"
//    }
//
//    private var healthMessageText: String? {
//        if let error = healthError {
//            return error
//        }
//        switch healthAuthResult {
//        case .denied:
//            return "Grant Health permissions to show daily progress."
//        case .unavailable:
//            return "Health data is unavailable on this device."
//        default:
//            return stepCount == nil && heartRate == nil ? "Authorize HealthKit to surface more insights." : nil
//        }
//    }
//
//    @ViewBuilder
//    private func healthActionButton() -> some View {
//        if healthAuthResult == .denied {
//            healthButton(title: "Open Settings") {
//                openHealthSettings()
//            }
//        } else if healthAuthResult != .granted {
//            healthButton(title: "Request access") {
//                requestHealthData(force: true)
//            }
//        } else if stepCount == nil || heartRate == nil {
//            healthButton(title: "Refresh data") {
//                refreshHealthData()
//            }
//        }
//    }
//
//    private func healthButton(title: String, action: @escaping () -> Void) -> some View {
//        Button(action: action) {
//            Text(title)
//                .font(.subheadline.weight(.semibold))
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 12)
//        }
//        .buttonStyle(.borderedProminent)
//        .tint(accent)
//    }
//
//    private func requestHealthData(force: Bool = false) {
//        if !force && healthAuthResult == .granted {
//            return
//        }
//        guard !isRequestInProgress else { return }
//        isRequestInProgress = true
//        healthError = nil
//
//        HealthKitManager.shared.requestAuthorization { result in
//            DispatchQueue.main.async {
//                self.healthAuthResult = result
//                self.isRequestInProgress = false
//            }
//            switch result {
//            case .granted:
//                fetchSteps()
//                fetchHeartRate()
//                fetchSleep()
//            case .denied:
//                DispatchQueue.main.async {
//                    healthError = "Grant Health permissions to show daily progress."
//                }
//            case .unavailable:
//                DispatchQueue.main.async {
//                    healthError = "Health data is unavailable on this device."
//                }
//            }
//        }
//   }

//    private func refreshHealthData() {
//        healthError = nil
//        fetchSteps()
//        fetchHeartRate()
//        fetchSleep()
//    }
//
//    private func fetchSteps() {
//        HealthKitManager.shared.fetchTodayStepCount { value in
//            DispatchQueue.main.async {
//                if let value = value {
//                    stepCount = value
//                } else {
//                    healthError = "Could not read today's steps."
//                }
//            }
//        }
//    }
//
//    private func fetchHeartRate() {
//        HealthKitManager.shared.fetchLatestHeartRate { value in
//            DispatchQueue.main.async {
//                if let value = value {
//                    heartRate = value
//                } else {
//                    healthError = "Could not read heart rate."
//                }
//            }
//        }
//    }
//
//    private func fetchSleep() {
//        HealthKitManager.shared.fetchLastNightSleepHours { hours in
//            DispatchQueue.main.async {
//                sleepHours = hours
//            }
//        }
//    }
//
//    private func openHealthSettings() {
//        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
//        openURL(url)
//    }

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
            NotificationManager.shared.ensureAuthorization { granted, _ in
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
            NotificationManager.shared.cancelReminders(for: habit)
            habit.reminders.removeAll()
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
        NotificationManager.shared.ensureAuthorization { granted, _ in
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
