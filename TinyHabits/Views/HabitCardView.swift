import SwiftUI
import HabitCore
import FledgeUI

/// A habit card in all its states (docs/DESIGN.md §6.1). One accessibility element with custom actions.
struct HabitCardView: View {
    let model: HabitCardModel
    let onToggleDone: () -> Void
    let onSkip: () -> Void
    let onUndoSkip: () -> Void
    let onReadyToFly: () -> Void
    let onPause: () -> Void
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var confirmDelete = false

    private var color: Color { FledgeTheme.habitColor(model.colorKey) }
    private var status: EntryStatus { model.progress.status }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FledgeTheme.Space.m))
            : AnyLayout(HStackLayout(alignment: .center, spacing: FledgeTheme.Space.l))

        layout {
            Button(action: status == .skipped ? onUndoSkip : onToggleDone) {
                HabitRing(fraction: model.progress.fraction, status: status, color: color, symbol: status == .done ? "checkmark" : model.symbol)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Spacer(minLength: FledgeTheme.Space.s)
                    SourceBadge(isAuto: model.isAuto)
                }
                Text(model.valueText)
                    .font(.subheadline.monospacedDigit())
                    .fontDesign(.rounded)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
                flightRow
            }
        }
        .padding(FledgeTheme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FledgeTheme.Palette.card, in: .rect(cornerRadius: FledgeTheme.Radius.card))
        .overlay {
            if model.isReadyToFly {
                RoundedRectangle(cornerRadius: FledgeTheme.Radius.card)
                    .strokeBorder(FledgeTheme.Palette.gold, lineWidth: 2)
            }
        }
        .sensoryFeedback(.success, trigger: status) { _, new in new == .done }
        .contextMenu { menuItems }
        .confirmationDialog("Delete \(model.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete habit and its history", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: status == .done ? "Undo done" : "Mark done", onToggleDone)
        .accessibilityAction(named: "Skip today", onSkip)
        .accessibilityAction(named: "Pause", onPause)
    }

    @ViewBuilder
    private var flightRow: some View {
        if model.isReadyToFly {
            Button(action: onReadyToFly) {
                Label("Ready to fly", systemImage: "sparkles")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, FledgeTheme.Space.m)
                    .padding(.vertical, FledgeTheme.Space.xs)
                    .background(FledgeTheme.Palette.gold.opacity(0.15), in: .capsule)
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
            Button("Undo done", systemImage: "arrow.uturn.backward", action: onToggleDone)
        } else {
            Button("Mark done", systemImage: "checkmark", action: onToggleDone)
        }
        if status == .skipped {
            Button("Undo rest day", systemImage: "arrow.uturn.backward", action: onUndoSkip)
        } else if status != .done {
            Button("Rest day", systemImage: "moon.zzz", action: onSkip)
        }
        if model.isReadyToFly {
            Button("Let it fly", systemImage: "bird", action: onReadyToFly)
        }
        Divider()
        Button("Pause", systemImage: "pause", action: onPause)
        Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
    }

    private var accessibilityText: String {
        let source = model.isAuto ? "from Apple Health" : "tap to log"
        return "\(model.name), \(model.valueText), \(source), \(model.flightText)"
    }
}

/// "Health" or "Tap" mini-badge.
struct SourceBadge: View {
    let isAuto: Bool

    var body: some View {
        Label(isAuto ? "Health" : "Tap", systemImage: isAuto ? "heart.fill" : "hand.tap.fill")
            .font(.caption)
            .foregroundStyle(isAuto ? FledgeTheme.Palette.skyText : FledgeTheme.Palette.ink2)
            .labelStyle(.titleAndIcon)
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
                Image(systemName: "bird")
                    .font(.title2)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
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
