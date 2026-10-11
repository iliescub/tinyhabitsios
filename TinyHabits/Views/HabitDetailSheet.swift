import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// Habit detail (docs/DESIGN.md §6.2): hero ring, flight track, 12-week heatmap, stats, actions.
struct HabitDetailSheet: View {
    let habit: Habit
    let day: DayKey
    let onReadyToFly: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    private var color: Color { FledgeTheme.habitColor(habit.colorKey) }
    private var history: [DaySnapshot] { habit.logs?.compactMap(\.snapshot) ?? [] }
    private var startedOn: DayKey { DayKey(habit.startedAt, dayEndHour: FledgeSettings.dayEndHour) }
    private var todayLog: DayLog? { habit.logs?.first { $0.dayKey == day.rawValue } }

    var body: some View {
        let card = HabitCardModel(
            name: habit.name, symbol: habit.symbol, colorKey: habit.colorKey, source: habit.source,
            target: habit.target, unit: habit.unit, cadence: habit.cadence, startedOn: startedOn, today: day,
            todayValue: todayLog?.value ?? 0, todayStatus: todayLog?.status ?? .pending,
            todayCompletedBy: todayLog?.completedBy, history: history
        )
        let stats = HabitDetailStats(snapshots: history, cadence: habit.cadence, startedOn: startedOn, today: day)

        NavigationStack {
            ScrollView {
                VStack(spacing: FledgeTheme.Space.xl) {
                    hero(card)
                    flightCard(stats, isReady: card.isReadyToFly)
                    DetailCard(title: "Last 12 weeks") {
                        HeatmapView(
                            model: HeatmapModel(snapshots: history, startedOn: startedOn, today: day),
                            color: color
                        )
                    }
                    statsRow(stats)
                }
                .padding(FledgeTheme.screenMargin)
            }
            .background(FledgeTheme.Palette.cloud)
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu("More", systemImage: "ellipsis") {
                        Button("Edit", systemImage: "pencil") { isEditing = true }
                        Button("Pause", systemImage: "pause") {
                            perform { try context.pause(habitID: habit.id) }
                            dismiss()
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .sheet(isPresented: $isEditing) { EditHabitSheet(habit: habit) }
            .confirmationDialog("Delete \(habit.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete habit and its history", role: .destructive) {
                    dismiss()
                    perform { try context.deleteHabit(habitID: habit.id) }
                }
            }
            .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func hero(_ card: HabitCardModel) -> some View {
        VStack(spacing: FledgeTheme.Space.m) {
            Button {
                perform { try context.setDone(card.progress.status != .done, habitID: habit.id, on: day, by: .manual) }
            } label: {
                HabitRing(
                    fraction: card.progress.fraction,
                    status: card.progress.status,
                    color: color,
                    symbol: card.progress.status == .done ? "checkmark" : habit.symbol,
                    size: FledgeTheme.Ring.detail,
                    lineWidth: 14
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(card.progress.status == .done ? "Undo done" : "Mark done")
            .sensoryFeedback(.success, trigger: card.progress.status) { _, new in new == .done }

            Text(card.valueText)
                .font(.title3.weight(.semibold).monospacedDigit())
                .fontDesign(.rounded)
                .foregroundStyle(FledgeTheme.Palette.ink)
            Label(
                habit.source.isAuto ? "Completes from Apple Health" : "Tap the ring to log",
                systemImage: habit.source.isAuto ? "heart.fill" : "hand.tap.fill"
            )
            .font(.footnote)
            .foregroundStyle(habit.source.isAuto ? FledgeTheme.Palette.skyText : FledgeTheme.Palette.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FledgeTheme.Space.s)
    }

    private func flightCard(_ stats: HabitDetailStats, isReady: Bool) -> some View {
        DetailCard(title: "Fledge progress") {
            VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
                LargeFlightTrack(fraction: stats.flightFraction, tick: stats.tickFraction, color: color)
                HStack {
                    Text("Day 0")
                    Spacer()
                    Text("Can fly from day \(stats.rule.minDays)")
                    Spacer()
                    Text("Day \(stats.rule.suggestedDays)")
                }
                .font(.caption)
                .foregroundStyle(FledgeTheme.Palette.ink2)
                Text(stats.flightLine)
                    .font(.subheadline)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                if isReady {
                    PrimaryActionButton(title: "Let it fly", systemImage: "bird") {
                        dismiss()
                        onReadyToFly()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func statsRow(_ stats: HabitDetailStats) -> some View {
        VStack(spacing: FledgeTheme.Space.m) {
            HStack(spacing: FledgeTheme.Space.m) {
                StatTile(title: "Current streak", value: stats.streakText)
                StatTile(title: "Best streak", value: stats.bestText)
                StatTile(title: "Last 30 days", value: stats.rateText)
            }
            if let left = stats.restDaysLeft {
                Text(left == 1 ? "1 rest day left this month" : "\(left) rest days left this month")
                    .font(.footnote)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { errorMessage = error.localizedDescription }
    }
}

struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
            Text(title)
                .font(.headline)
                .foregroundStyle(FledgeTheme.Palette.ink)
            content
        }
        .padding(FledgeTheme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FledgeTheme.Palette.card, in: .rect(cornerRadius: FledgeTheme.Radius.card))
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .fontDesign(.rounded)
                .foregroundStyle(FledgeTheme.Palette.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
        .padding(FledgeTheme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FledgeTheme.Palette.card, in: .rect(cornerRadius: FledgeTheme.Radius.tile))
        .accessibilityElement(children: .combine)
    }
}

/// Day 0 → suggested-day track with the day-30 tick and a bird marker.
struct LargeFlightTrack: View {
    let fraction: Double
    let tick: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(FledgeTheme.Palette.hairline).frame(height: 8)
                Capsule().fill(color).frame(width: max(8, width * min(fraction, 1)), height: 8)
                Rectangle().fill(FledgeTheme.Palette.gold).frame(width: 3, height: 18)
                    .offset(x: width * tick - 1.5)
                Image(systemName: "bird.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .offset(x: min(width - 20, max(0, width * min(fraction, 1) - 10)), y: -18)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 44)
        .accessibilityHidden(true)
    }
}

/// 12 columns (weeks) × 7 rows (weekdays).
struct HeatmapView: View {
    let model: HeatmapModel
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(model.weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 4) {
                    ForEach(week) { cell in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fill(for: cell.state))
                            .overlay {
                                if cell.state == .rest {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(color.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                                }
                                if cell.isToday {
                                    RoundedRectangle(cornerRadius: 4).strokeBorder(FledgeTheme.Palette.ink, lineWidth: 1.5)
                                }
                            }
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    private func fill(for state: HeatmapModel.CellState) -> Color {
        switch state {
        case .done: color
        case .rest: color.opacity(0.08)
        case .missed, .pending: FledgeTheme.Palette.hairline
        case .beforeStart, .future: FledgeTheme.Palette.hairline.opacity(0.35)
        }
    }

    private var accessibilitySummary: String {
        let cells = model.weeks.flatMap { $0 }
        let done = cells.filter { $0.state == .done }.count
        let rest = cells.filter { $0.state == .rest }.count
        return "Last 12 weeks: \(done) days done, \(rest) rest days"
    }
}
