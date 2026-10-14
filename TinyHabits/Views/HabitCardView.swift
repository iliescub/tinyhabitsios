import SwiftUI
import HabitCore
import FledgeUI

/// What a card can do; supplied by Today.
struct HabitCardActions {
    let open: () -> Void
    let toggleDone: () -> Void
    let addIncrement: () -> Void
    let logAmount: () -> Void
    let skip: () -> Void
    let undoSkip: () -> Void
    let readyToFly: () -> Void
    let pause: () -> Void
    let delete: () -> Void
}

/// A habit card in all its states (docs/DESIGN.md §6.1). One accessibility element with custom actions.
struct HabitCardView: View {
    let model: HabitCardModel
    let actions: HabitCardActions
    var showsNoDataHint = false
    /// When Apple Health last updated today's value (auto habits).
    var lastUpdated: Date?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var confirmDelete = false
    @State private var bursts = 0

    private var color: Color { FledgeTheme.habitColor(model.colorKey) }
    private var status: EntryStatus { model.progress.status }

    var body: some View {
        styledCard
            .contextMenu { menuItems }
            .confirmationDialog("Delete \(model.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete habit and its history", role: .destructive) { actions.delete() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityText))
            .accessibilityHint(Text("Opens details"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { actions.open() }
            .accessibilityAction(named: Text(doneActionName)) { actions.toggleDone() }
            .accessibilityAction(named: Text("Rest day")) { actions.skip() }
            .accessibilityAction(named: Text("Pause")) { actions.pause() }
    }

    private var styledCard: some View {
        cardContent
            .padding(FledgeTheme.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fledgeCard(tint: status == .done ? color : nil)
            .contentShape(.rect(cornerRadius: FledgeTheme.Radius.card))
            .onTapGesture { actions.open() }
            .overlay { readyOutline }
            .sensoryFeedback(.success, trigger: status) { _, new in new == .done }
            .onChange(of: status) { old, new in
                if new == .done && old != .done { bursts += 1 }
            }
    }

    private var cardContent: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FledgeTheme.Space.m))
            : AnyLayout(HStackLayout(alignment: .center, spacing: FledgeTheme.Space.l))

        return layout {
            ringButton
            VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                HStack(alignment: .firstTextBaseline, spacing: FledgeTheme.Space.s) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Spacer(minLength: 0)
                    sourceMeta
                }
                ValueLine(model: model)
                if showsNoDataHint {
                    NoDataHint()
                } else {
                    flightRow
                }
            }
        }
    }

    private var ringButton: some View {
        Button {
            if status == .skipped { actions.undoSkip() } else { actions.toggleDone() }
        } label: {
            HabitRing(fraction: model.progress.fraction, status: status, color: color, symbol: model.symbol)
                .overlay { FeatherBurst(trigger: bursts, color: color) }
        }
        .buttonStyle(.plain)
    }

    /// Where the value comes from: "♥ 4 min ago" for Apple Health, a tap hint for manual habits still to do.
    /// Nothing on rest days: the log's timestamp is then the skip, not a Health update.
    @ViewBuilder
    private var sourceMeta: some View {
        if model.isAuto && status != .skipped {
            Label {
                Text(HabitCardModel.freshness(lastUpdated: lastUpdated, now: .now) ?? "Apple Health")
            } icon: {
                Image(systemName: "heart.fill").foregroundStyle(FledgeTheme.Palette.sky)
            }
            .font(FledgeTheme.Typeface.meta)
            .foregroundStyle(FledgeTheme.Palette.ink2)
            .lineLimit(1)
        } else if status == .pending {
            Text("Tap the ring")
                .font(FledgeTheme.Typeface.meta)
                .foregroundStyle(FledgeTheme.Palette.ink2)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var readyOutline: some View {
        if model.isReadyToFly {
            RoundedRectangle(cornerRadius: FledgeTheme.Radius.card, style: .continuous)
                .strokeBorder(FledgeTheme.Palette.gold, lineWidth: 1.5)
        }
    }

    private var doneActionName: String {
        status == .done ? "Undo done" : "Mark done"
    }

    @ViewBuilder
    private var flightRow: some View {
        if model.isReadyToFly {
            Button(action: actions.readyToFly) {
                Label { Text("Ready to fly") } icon: { Image.fledgeGlyph(height: 13) }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, FledgeTheme.Space.m)
                    .padding(.vertical, 6)
                    .background(FledgeTheme.Palette.gold.opacity(0.18), in: .capsule)
                    .foregroundStyle(FledgeTheme.Palette.ink)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: FledgeTheme.Space.s) {
                FlightTrack(fraction: model.flightFraction)
                Text(model.flightText)
                    .font(.footnote)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        if status == .done {
            Button("Undo done", systemImage: "arrow.uturn.backward", action: actions.toggleDone)
        } else {
            Button("Mark done", systemImage: "checkmark", action: actions.toggleDone)
        }
        if model.isManualQuantity && status != .done {
            Button(model.incrementText, systemImage: "plus", action: actions.addIncrement)
            Button("Log amount…", systemImage: "number", action: actions.logAmount)
        }
        if status == .skipped {
            Button("Undo rest day", systemImage: "arrow.uturn.backward", action: actions.undoSkip)
        } else if status != .done {
            Button("Rest day", systemImage: "moon.zzz", action: actions.skip)
        }
        if model.isReadyToFly {
            Button(action: actions.readyToFly) {
                Label { Text("Let it fly") } icon: { Image.fledgeGlyph() }
            }
        }
        Divider()
        Button("Details", systemImage: "chart.bar", action: actions.open)
        Button("Pause", systemImage: "pause", action: actions.pause)
        Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
    }

    private var accessibilityText: String {
        let source = model.isAuto ? "from Apple Health" : "tap to log"
        return "\(model.name), \(model.valueText), \(source), \(model.flightText)"
    }
}

/// "4,210 / 6,000 steps" with the number large; words ("Done", "Rest day") a step smaller.
struct ValueLine: View {
    let model: HabitCardModel
    var large = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FledgeTheme.Space.xs) {
            Text(model.metricText)
                .font(metricFont)
                .foregroundStyle(model.progress.status == .skipped ? FledgeTheme.Palette.ink2 : FledgeTheme.Palette.ink)
                .contentTransition(.numericText())
            if let goal = model.goalText {
                Text(goal)
                    .font(large ? .body : .subheadline)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .animation(.snappy, value: model.metricText)
    }

    private var metricFont: Font {
        if large {
            return .system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit()
        }
        return model.goalText == nil
            ? .system(.title3, design: .rounded, weight: .bold)
            : FledgeTheme.Typeface.metric
    }
}

/// Shown when an auto habit has had no Health data for three days (HK-4). Read denial looks the same as no data.
struct NoDataHint: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: "x-apple-health://") { openURL(url) }
        } label: {
            Label("Not seeing data? Check Health access", systemImage: "heart.text.square")
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.skyText)
        }
        .buttonStyle(.plain)
    }
}

/// Thin day-0 → day-66 track with a gold tick where graduation becomes possible (day 30).
struct FlightTrack: View {
    let fraction: Double
    var tick: Double = Double(GraduationRule.standard.minDays) / Double(GraduationRule.standard.suggestedDays)

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(FledgeTheme.Palette.hairline)
                Capsule().fill(FledgeTheme.Palette.ink2.opacity(0.6))
                    .frame(width: proxy.size.width * max(0.04, min(fraction, 1)))
                Rectangle().fill(FledgeTheme.Palette.gold)
                    .frame(width: 2, height: 8)
                    .offset(x: proxy.size.width * tick - 1)
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 120)
        .accessibilityHidden(true)
    }
}

/// An open slot in the nest.
struct EmptySlotCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FledgeTheme.Space.l) {
                FledgeBird(.peeking, style: .glyph)
                    .foregroundStyle(FledgeTheme.Palette.ink2.opacity(0.7))
                    .frame(width: FledgeTheme.Ring.card * 0.8)
                    .frame(width: FledgeTheme.Ring.card, height: FledgeTheme.Ring.card)
                VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                    Text("Add a habit")
                        .font(.headline)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Text("There's room in the nest.")
                        .font(.subheadline)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
                Spacer()
            }
            .padding(FledgeTheme.Space.l)
            .overlay {
                RoundedRectangle(cornerRadius: FledgeTheme.Radius.card)
                    .strokeBorder(FledgeTheme.Palette.hairline, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
            }
            .contentShape(.rect(cornerRadius: FledgeTheme.Radius.card))
        }
        .buttonStyle(.plain)
    }
}
