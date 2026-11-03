import SwiftUI
import HabitCore
import FledgeUI

/// Fresh starts, not failures (RES-5, UXR-3): after a quiet week, the next landmark day and a choice of plan. Never red.
struct FreshStartCard: View {
    let offer: FreshStart.Offer
    let samePlan: () -> Void
    let smallerSteps: () -> Void
    let notNow: () -> Void

    private var landmarkName: String {
        switch offer.landmark {
        case .newYear: "New Year's Day"
        case .newMonth: "The 1st"
        case .newWeek: offer.day.date().formatted(.dateTime.weekday(.wide))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
            HStack(alignment: .top, spacing: FledgeTheme.Space.m) {
                Image(systemName: "sunrise.fill")
                    .font(.title2)
                    .foregroundStyle(FledgeTheme.Palette.gold)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                    Text("\(landmarkName) is a fresh start.")
                        .font(.headline)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Text("This week was quiet, and that's part of it. Pick up again then with the same plan, or with smaller steps.")
                        .font(.subheadline)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: FledgeTheme.Space.s) { buttons }
                VStack(alignment: .leading, spacing: FledgeTheme.Space.s) { buttons }
            }
        }
        .padding(FledgeTheme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fledgeCard(cornerRadius: FledgeTheme.Radius.tile, tint: FledgeTheme.Palette.gold)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var buttons: some View {
        Button("Same plan", action: samePlan)
            .buttonStyle(.borderedProminent)
            .tint(FledgeTheme.Palette.ink)
        Button("Smaller steps", action: smallerSteps)
            .buttonStyle(.bordered)
            .tint(FledgeTheme.Palette.ink)
        Button("Not now", action: notNow)
            .buttonStyle(.borderless)
            .tint(FledgeTheme.Palette.skyText)
    }
}
