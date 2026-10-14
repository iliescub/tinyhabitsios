import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// Habit detail (docs/DESIGN.md §6.2, v2 in docs/UI-REDESIGN.md UX-7): today's number as the hero, stats above the fold,
/// the journey to flying, a labelled 12-week heatmap, and "Let it fly" pinned to the bottom when the habit is ready.
/// On iPad, when the window is wide, the same content is shown as a pane beside the nest (docs/DESIGN.md §12).
struct HabitDetailSheet: View {
    enum Style {
        /// iPhone and narrow windows: a sheet with Done and a More menu in its toolbar.
        case sheet
        /// Wide iPad windows: a pane next to the nest, with its own header.
        case pane
    }

    let habit: Habit
    let day: DayKey
    var style: Style = .sheet
    let onReadyToFly: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isEditing = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    @State private var bursts = 0

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

        let content = ScrollView {
                VStack(spacing: FledgeTheme.Space.l) {
                    hero(card)
                    statsRow(stats)
                    DetailCard(title: "Journey to fly") {
                        let flyDate = FlightForecast.flyDate(snapshots: history, cadence: habit.cadence, startedOn: startedOn, today: day)
                        let journey = JourneyModel(stats: stats, startedOn: startedOn, flyDate: flyDate)
                        VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
                            JourneyTrack(model: journey, color: color)
                            Text(journey.headline)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FledgeTheme.Palette.ink)
                            Text(journey.status)
                                .font(.footnote)
                                .foregroundStyle(FledgeTheme.Palette.ink2)
                            if let forecast = journey.forecast {
                                // GRAD-4: a date to look forward to.
                                Label {
                                    Text(forecast)
                                } icon: {
                                    FledgeBird(.flying, style: .tinted(color)).frame(width: 18)
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(FledgeTheme.Palette.ink)
                                .padding(.top, 2)
                            }
                        }
                    }
                    DetailCard(title: "Last 12 weeks") {
                        HeatmapView(
                            model: HeatmapModel(snapshots: history, startedOn: startedOn, today: day),
                            color: color
                        )
                    }
                    if let left = stats.restDaysLeft {
                        Label(left == 1 ? "1 rest day left this month" : "\(left) rest days left this month", systemImage: "moon.zzz")
                            .font(.footnote)
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                }
                .padding(FledgeTheme.screenMargin)
            }
            .background(FledgeTheme.Palette.cloud)
            .safeAreaInset(edge: .bottom) {
                if card.isReadyToFly {
                    PrimaryActionButton(title: "Let it fly", icon: .fledgeGlyph()) {
                        close()
                        onReadyToFly()
                    }
                    .padding(.bottom, FledgeTheme.Space.s)
                }
            }
            .sheet(isPresented: $isEditing) { EditHabitSheet(habit: habit) }
            .confirmationDialog("Delete \(habit.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete habit and its history", role: .destructive) {
                    close()
                    perform(structural: true) { try context.deleteHabit(habitID: habit.id) }
                }
            }
            .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }

        switch style {
        case .sheet:
            NavigationStack {
                content
                    .navigationTitle(habit.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { dismiss() }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            moreMenu
                        }
                    }
            }
        case .pane:
            VStack(spacing: 0) {
                HStack {
                    Text(habit.name)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(FledgeTheme.Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    moreMenu
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .tint(FledgeTheme.Palette.ink)
                }
                .padding(.horizontal, FledgeTheme.screenMargin)
                .padding(.top, FledgeTheme.Space.l)
                content
            }
            .frame(maxWidth: NestLayout.readableWidth)
            .frame(maxWidth: .infinity)
            .background(FledgeTheme.Palette.cloud)
        }
    }

    private var moreMenu: some View {
        Menu("More", systemImage: "ellipsis.circle") {
            Button("Edit", systemImage: "pencil") { isEditing = true }
            Button("Pause", systemImage: "pause") {
                perform(structural: true) { try context.pause(habitID: habit.id) }
                close()
            }
            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
        }
    }

    /// Dismisses the sheet; a pane has nothing to dismiss (Today picks another habit when this one leaves).
    private func close() {
        if style == .sheet { dismiss() }
    }

    // MARK: - Hero

    private func hero(_ card: HabitCardModel) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FledgeTheme.Space.l))
            : AnyLayout(HStackLayout(alignment: .center, spacing: FledgeTheme.Space.xl))

        return layout {
            Button {
                let wasDone = card.progress.status == .done
                perform { try context.setDone(!wasDone, habitID: habit.id, on: day, by: .manual) }
                if !wasDone { bursts += 1 }
            } label: {
                HabitRing(
                    fraction: card.progress.fraction,
                    status: card.progress.status,
                    color: color,
                    symbol: habit.symbol,
                    size: 124,
                    lineWidth: 12
                )
                .overlay { FeatherBurst(trigger: bursts, color: color) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(card.progress.status == .done ? "Undo done" : "Mark done")
            .sensoryFeedback(.success, trigger: card.progress.status) { _, new in new == .done }

            VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                Text("Today").fledgeEyebrow()
                ValueLine(model: card, large: true)
                Label {
                    Text(sourceLine)
                } icon: {
                    Image(systemName: habit.source.isAuto ? "heart.fill" : "hand.tap.fill")
                        .foregroundStyle(habit.source.isAuto ? FledgeTheme.Palette.sky : FledgeTheme.Palette.ink2)
                }
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.ink2)
                .padding(.top, FledgeTheme.Space.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
        .padding(.top, FledgeTheme.Space.s)
    }

    private var sourceLine: String {
        guard habit.source.isAuto else { return "Tap the ring to log" }
        let fresh = HabitCardModel.freshness(lastUpdated: todayLog?.updatedAt, now: .now)
        return fresh.map { "Apple Health · \($0)" } ?? "Completes from Apple Health"
    }

    private func statsRow(_ stats: HabitDetailStats) -> some View {
        let tiles = [
            ("Current streak", stats.streakText),
            ("Best streak", stats.bestText),
            ("Last 30 days", stats.rateText),
        ]
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: FledgeTheme.Space.m))
            : AnyLayout(HStackLayout(spacing: FledgeTheme.Space.m))
        return layout {
            ForEach(tiles, id: \.0) { tile in
                StatTile(title: tile.0, value: tile.1)
            }
        }
    }

    private func perform(structural: Bool = false, _ action: () throws -> Void) {
        do {
            try action()
            AppRefresh.afterWrite(context: context, structural: structural)
        } catch {
            errorMessage = error.localizedDescription
        }
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
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(FledgeTheme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fledgeCard()
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
            Text(value)
                .font(FledgeTheme.Typeface.metric)
                .foregroundStyle(FledgeTheme.Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
        .padding(FledgeTheme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
        .accessibilityElement(children: .combine)
    }
}

/// 12 columns (weeks) × 7 rows (weekdays), with weekday and month labels and a legend.
struct HeatmapView: View {
    let model: HeatmapModel
    let color: Color

    private let spacing: CGFloat = 4
    private let labelWidth: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
            GeometryReader { proxy in
                let columns = CGFloat(model.weeks.count)
                let cell = (proxy.size.width - labelWidth - spacing * columns) / columns
                ZStack(alignment: .topLeading) {
                    ForEach(model.monthLabels, id: \.week) { label in
                        Text(label.text)
                            .font(.caption2)
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                            .fixedSize()
                            .offset(x: labelWidth + spacing + CGFloat(label.week) * (cell + spacing))
                    }
                    HStack(alignment: .top, spacing: spacing) {
                        VStack(spacing: spacing) {
                            ForEach(Array(model.weekdayLabels.enumerated()), id: \.offset) { _, label in
                                Text(label)
                                    .font(.caption2)
                                    .foregroundStyle(FledgeTheme.Palette.ink2)
                                    .fixedSize()
                                    .frame(minWidth: labelWidth, minHeight: cell)
                            }
                        }
                        ForEach(Array(model.weeks.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: spacing) {
                                ForEach(week) { cellView($0).frame(width: cell, height: cell) }
                            }
                        }
                    }
                    .offset(y: 18)
                }
            }
            .aspectRatio(gridAspectRatio, contentMode: .fit)

            HStack(spacing: FledgeTheme.Space.l) {
                legend("Done") { RoundedRectangle(cornerRadius: 3).fill(color) }
                legend("Rest") { RoundedRectangle(cornerRadius: 3).strokeBorder(color.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])) }
                legend("Today") { RoundedRectangle(cornerRadius: 3).strokeBorder(FledgeTheme.Palette.ink, lineWidth: 1.5) }
                if model.hasEarlierDays {
                    // HEAD-1: days met before the habit started in Fledge, read from Apple Health.
                    legend("Before Fledge") { RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.3)) }
                }
            }
            .font(.caption2)
            .foregroundStyle(FledgeTheme.Palette.ink2)
            .accessibilityHidden(true)
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    /// Width ÷ height of the labelled grid, so GeometryReader gets a fixed height.
    private var gridAspectRatio: CGFloat {
        // 12 columns + label column; 7 rows + month label row (≈ 18 pt, approximated as 0.9 cells).
        CGFloat(model.weeks.count) / (7 + 0.9) * 1.08
    }

    private func cellView(_ cell: HeatmapModel.Cell) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fill(for: cell.state))
            .overlay {
                if cell.state == .rest {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(color.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                }
                if cell.isToday {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(FledgeTheme.Palette.ink, lineWidth: 1.5)
                }
            }
    }

    private func legend<Swatch: View>(_ title: String, @ViewBuilder swatch: () -> Swatch) -> some View {
        HStack(spacing: 5) {
            swatch().frame(width: 10, height: 10)
            Text(title)
        }
    }

    private func fill(for state: HeatmapModel.CellState) -> Color {
        switch state {
        case .done: color
        case .earlier: color.opacity(0.3)
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
