//
//  FocusView.swift
//  TinyHabits
//
//  Redesigned to motivate daily completions with rich cards and progress.
//

import SwiftUI
import SwiftData

struct FocusView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("profile_name") private var profileName: String = ""
    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue
    @AppStorage("motivation_dailyQuotes") private var showDailyQuotes: Bool = true
    @AppStorage("motivation_haptics") private var enableHaptics: Bool = true

    let habits: [Habit]

    @State private var animateHero = false
    @State private var dailyQuote: String = ""

    private var accentColor: Color { AccentTheme(rawValue: accentRaw)?.color ?? .blue }
    private var accentGradient: [Color] {
        [
            accentColor.adjustingBrightness(by: -0.06),
            accentColor.adjustingBrightness(by: 0.14)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard

                    if habits.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your focus today")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                ForEach(displayedHabits) { habit in
                        let snapshot = progress(for: habit)
                        NavigationLink {
                            HabitDetailView(habit: habit)
                                } label: {
                                    HabitCardView(
                                        habit: habit,
                                    snapshot: snapshot,
                                    accent: accentColor,
                                    onToggleDone: { toggleDone(for: habit) },
                                    onIncrement: { incrementProgress(for: habit) }
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
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) {
                animateHero = true
            }
            dailyQuote = buildDailyQuote()
        }
    }

    private var displayedHabits: [Habit] {
        // Deduplicate by normalized name so repeated seeds don't surface as repeated cards.
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
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(colors: accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: accentColor.opacity(0.25), radius: 20, y: 12)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(greetingTitle)
                        .font(.title3.bold())
                        .foregroundStyle(.white.opacity(0.9))
                    Image(systemName: "sparkles")
                        .foregroundStyle(.white.opacity(0.9))
                        .symbolEffect(.pulse.byLayer, isActive: animateHero)
                }

                Text(heroMessage)
                    .foregroundStyle(.white.opacity(0.85))

                if showDailyQuotes {
                    Text("“\(dailyQuote)”")
                        .font(.subheadline.italic())
                        .foregroundStyle(.white.opacity(0.9))
                }

                HStack(spacing: 16) {
                    progressChip(title: "Done", value: "\(completedCount)/\(max(displayedHabits.count, 1))")
                    progressChip(title: "Momentum", value: momentumText)
                    Spacer()
                }

                if let nextHabit = nextPendingHabit {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next up")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            Text(nextHabit.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Button {
                            toggleDone(for: nextHabit)
                        } label: {
                            Text("Start")
                                .font(.headline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.18))
                                .clipShape(Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 110, height: 110)
                .offset(x: 20, y: -30)
                .blur(radius: 16)
                .opacity(animateHero ? 1 : 0.2)
        }
    }

    private func progressChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var greetingTitle: String {
        let base = profileName.isEmpty ? "Welcome back" : "You got this, \(profileName)"
        return base
    }

    private var heroMessage: String {
        switch completedCount {
        case 0:
            return "Pick one tiny habit and knock it out. Momentum beats motivation."
        case 1..<displayedHabits.count:
            return "Great start! Keep stacking wins to lock in your streak."
        default:
            return "Perfect day. Enjoy the glow, you earned it."
        }
    }

    private var completedCount: Int {
        habits.filter { progress(for: $0).status == .done }.count
    }

    private var momentumText: String {
        let percent = Int(progressRatio * 100)
        return "\(percent)%"
    }

    private var progressRatio: Double {
        guard !displayedHabits.isEmpty else { return 0 }
        let total = displayedHabits.reduce(0.0) { partial, habit in
            partial + progress(for: habit).completion
        }
        return total / Double(displayedHabits.count)
    }

    private var nextPendingHabit: Habit? {
        displayedHabits.first { progress(for: $0).status != .done }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bolt.heart")
                .font(.system(size: 46))
                .foregroundStyle(accentColor)
            Text("No habits for today yet.")
                .font(.headline)
            Text("Add up to three tiny habits to keep your streaks alive.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func progress(for habit: Habit) -> HabitProgress {
        let target = max(1, habit.dailyTarget)
        guard let entry = fetchTodayEntry(for: habit) else {
            return HabitProgress(status: .pending, current: 0, target: target, completion: 0)
        }

        let completion: Double
        switch entry.status {
        case .done:
            completion = 1
        case .skipped:
            completion = 0
        case .pending:
            completion = min(Double(entry.progressValue) / Double(target), 1)
        }

        return HabitProgress(status: entry.status, current: entry.progressValue, target: target, completion: completion)
    }

    private func fetchTodayEntry(for habit: Habit) -> HabitEntry? {
        let calendar = Calendar.current
        let habitID = habit.id
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)

        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in
                entry.habit.id == habitID &&
                entry.date >= start &&
                entry.date < end
            },
            sortBy: [SortDescriptor(\HabitEntry.date, order: .reverse)]
        )
        return try? context.fetch(descriptor).first
    }

    private func ensureTodayEntry(for habit: Habit) -> HabitEntry {
        if let existing = fetchTodayEntry(for: habit) {
            return existing
        }
        let newEntry = HabitEntry(date: Date(), status: .pending, habit: habit, progressValue: 0)
        context.insert(newEntry)
        return newEntry
    }

    private func toggleDone(for habit: Habit) {
        Task { @MainActor in
            let entry = ensureTodayEntry(for: habit)
            if entry.status == .done {
                updateStatus(entry: entry, status: .pending)
                if enableHaptics { HapticManager.shared.play(.soft) }
            } else {
                updateStatus(entry: entry, status: .done)
                if enableHaptics { HapticManager.shared.play(.celebrate) }
            }
            persistContext()
        }
    }

    private func incrementProgress(for habit: Habit) {
        Task { @MainActor in
            let target = max(1, habit.dailyTarget)
            let entry = ensureTodayEntry(for: habit)
            let next = min(entry.progressValue + max(1, target / 4), target)
            entry.progressValue = next
            entry.status = next >= target ? .done : .pending
            persistContext()
            if enableHaptics { HapticManager.shared.play(next >= target ? .celebrate : .light) }
        }
    }

    private func persistContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("FocusView save error: \(error)")
        }
    }

    private func updateStatus(entry: HabitEntry, status: HabitStatus) {
        entry.status = status
        if status == .done {
            entry.progressValue = max(entry.progressValue, max(1, entry.habit.dailyTarget))
        }
        if status == .pending {
            entry.progressValue = min(entry.progressValue, max(0, entry.habit.dailyTarget - 1))
        }
    }

    private func buildDailyQuote() -> String {
        let quotes = [
            "Small steps, every day.",
            "Consistency beats intensity.",
            "Done is better than perfect.",
            "Tiny wins compound over time.",
            "Show up for your future self."
        ]
        let dayIndex = Calendar.current.component(.day, from: Date())
        return quotes[dayIndex % quotes.count]
    }
}

// MARK: - Supporting Models & Views

private struct HabitProgress {
    let status: HabitStatus
    let current: Int
    let target: Int
    let completion: Double

    var percentString: String {
        let percent = Int(completion * 100)
        return "\(percent)%"
    }
}

private struct HabitCardView: View {
    let habit: Habit
    let snapshot: HabitProgress
    let accent: Color
    let onToggleDone: () -> Void
    let onIncrement: () -> Void

    private var habitAccent: Color {
        AccentTheme(rawValue: habit.accentColorKey)?.color ?? accent
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(habitAccent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: habit.iconSystemName)
                        .font(.headline)
                        .foregroundStyle(habitAccent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                    Text(subtitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(snapshot.percentString)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(snapshot.status == .done ? .green : habitAccent)
                    ProgressRing(progress: snapshot.completion, accent: habitAccent)
                        .frame(width: 36, height: 36)
                }
            }

            HabitTrackingBar(
                current: snapshot.current,
                target: snapshot.target,
                accent: habitAccent,
                onIncrement: onIncrement
            )

            Button {
                onToggleDone()
            } label: {
                Label(snapshot.status == .done ? "Undo" : "Mark done", systemImage: snapshot.status == .done ? "arrow.uturn.left" : "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(habitAccent.opacity(0.9))
                    .clipShape(Capsule(style: .continuous))
                    .shadow(color: habitAccent.opacity(0.25), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        )
    }

    private var subtitleText: String {
        switch snapshot.status {
        case .done:
            return "Crushed for today."
        case .skipped:
            return "Skipped—reset tomorrow."
        case .pending:
            let remaining = max(snapshot.target - snapshot.current, 0)
            return remaining > 0 ? "\(remaining) to go" : "Finish and mark done"
        }
    }
}

private struct HabitTrackingBar: View {
    let current: Int
    let target: Int
    let accent: Color
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            GeometryReader { proxy in
                let ratio = min(max(Double(current) / Double(max(target, 1)), 0), 1)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [accent.opacity(0.9), accent.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 16)

            Button {
                onIncrement()
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(accent, in: Circle())
                    .shadow(color: accent.opacity(0.2), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Increment progress")
        }
        .frame(height: 24)
    }
}

private struct ProgressRing: View {
    let progress: Double
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [accent, accent.adjustingBrightness(by: 0.1), accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}
