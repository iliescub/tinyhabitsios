import SwiftUI
import HabitCore
import FledgeUI

/// The resolution above the nest (RES-7): the sentence, where the year stands, and the year strip.
struct ResolutionCard: View {
    let model: ResolutionHeaderModel

    private var accessibilityText: String {
        let why = model.why.isEmpty ? "" : " \(model.why)."
        let map = model.isFirstWeek
            ? "\(model.firstWeekDots.filter { $0 == .full }.count) of 7 first-week days fully met."
            : model.dotsSummary
        return "\(model.sentence).\(why) \(model.progressLine). \(map)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
            Text(model.sentence)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(FledgeTheme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !model.why.isEmpty {
                Text(model.why)
                    .font(.footnote.italic())
                    .foregroundStyle(FledgeTheme.Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(model.progressLine)
                .font(FledgeTheme.Typeface.meta)
                .foregroundStyle(FledgeTheme.Palette.ink2)
                .monospacedDigit()
            if model.isFirstWeek {
                FirstWeekRow(days: model.firstWeekDays, dots: model.firstWeekDots)
                    .padding(.top, FledgeTheme.Space.xs)
            } else {
                YearStrip(dots: model.dots, color: model.isKept ? FledgeTheme.Palette.gold : FledgeTheme.Palette.meadow)
                    .padding(.top, FledgeTheme.Space.xs)
                HStack {
                    Text("Jan")
                    Spacer()
                    Text("Dec")
                }
                .font(.caption2)
                .foregroundStyle(FledgeTheme.Palette.ink2)
                .accessibilityHidden(true)
            }
        }
        .padding(FledgeTheme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fledgeCard(cornerRadius: FledgeTheme.Radius.tile, tint: model.isKept ? FledgeTheme.Palette.gold : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }
}

/// Habits but no resolution (people coming from Fledge, or after letting one go): one tap to make them a resolution.
struct MakeResolutionCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FledgeTheme.Space.m) {
                Image(systemName: "sunrise.fill").font(.title2).foregroundStyle(FledgeTheme.Palette.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make it a resolution").font(.headline).foregroundStyle(FledgeTheme.Palette.ink)
                    Text("Give these habits one goal for the year. They're kept when they all fly.")
                        .font(.footnote).foregroundStyle(FledgeTheme.Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(FledgeTheme.Palette.ink2)
            }
            .padding(FledgeTheme.Space.l)
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile, tint: FledgeTheme.Palette.gold)
        }
        .buttonStyle(.plain)
    }
}

/// Days 1–7 of a resolution (UXR-2): a dot per day under its weekday. Full and partial also differ by fill, never colour alone.
private struct FirstWeekRow: View {
    let days: [DayKey]
    let dots: [YearMap.Dot]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(zip(days, dots).enumerated()), id: \.offset) { _, pair in
                VStack(spacing: FledgeTheme.Space.xs) {
                    Text(pair.0.date().formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                    dot(pair.1)
                        .frame(width: 18, height: 18)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func dot(_ state: YearMap.Dot) -> some View {
        switch state {
        case .full:
            Circle().fill(FledgeTheme.Palette.meadow)
                .overlay { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(FledgeTheme.Palette.onInk) }
        case .partial:
            Circle().strokeBorder(FledgeTheme.Palette.meadow, lineWidth: 2)
                .background(Circle().fill(FledgeTheme.Palette.meadow.opacity(0.35)).padding(5))
        case .empty:
            Circle().strokeBorder(FledgeTheme.Palette.ink2.opacity(0.35), lineWidth: 1.5)
        case .future, .before:
            Circle().fill(FledgeTheme.Palette.ink.opacity(0.08))
        }
    }
}
