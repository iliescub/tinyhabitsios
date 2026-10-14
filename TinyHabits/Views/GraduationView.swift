import SwiftUI
import HabitCore
import FledgeUI

/// Graduation (docs/DESIGN.md §6.4): the ring becomes a bird, and "Let it fly" sends it to the Flown shelf.
/// Reduce Motion: cross-fades only, no flight.
struct GraduationView: View {
    let habit: Habit
    let day: DayKey
    let onFly: () -> Void
    let onKeep: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .ring
    @Namespace private var hero

    private enum Phase { case ring, bird, flying }

    private var color: Color { FledgeTheme.habitColor(habit.colorKey) }

    var body: some View {
        let startedOn = DayKey(habit.startedAt, dayEndHour: FledgeSettings.dayEndHour)
        let stats = HabitDetailStats(snapshots: habit.logs?.compactMap(\.snapshot) ?? [], cadence: habit.cadence, startedOn: startedOn, today: day)

        ZStack {
            SkyBackground().ignoresSafeArea()
            VStack(spacing: FledgeTheme.Space.xl) {
                Spacer()
                ZStack {
                    if phase == .ring {
                        HabitRing(fraction: 1, status: .done, color: color, symbol: habit.symbol, size: FledgeTheme.Ring.detail, lineWidth: 14)
                            .matchedGeometryEffect(id: "hero", in: hero)
                            .transition(.opacity)
                    } else {
                        FledgeBird(phase == .flying ? .flying : .sitting, style: .tinted(color))
                            .frame(width: 170)
                            .shadow(color: FledgeTheme.Palette.ink.opacity(0.15), radius: 14, y: 8)
                            .matchedGeometryEffect(id: "hero", in: hero)
                            .offset(phase == .flying && !reduceMotion ? CGSize(width: -420, height: -700) : .zero)
                            .opacity(phase == .flying && reduceMotion ? 0 : 1)
                            .transition(.opacity)
                    }
                }
                .frame(height: 200)
                .accessibilityHidden(true)

                VStack(spacing: FledgeTheme.Space.s) {
                    Text("\(habit.name) is ready to fly.")
                        .font(.title.bold())
                        .fontDesign(.rounded)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                        .multilineTextAlignment(.center)
                    Text("\(stats.graduation.daysActive) days · \(stats.rateText) in the last \(stats.rule.windowDays) days")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                    Text("Flown habits keep tracking quietly. We'll nudge you only if it slips.")
                        .font(.subheadline)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                        .multilineTextAlignment(.center)
                        .padding(.top, FledgeTheme.Space.s)
                }
                .padding(.horizontal, FledgeTheme.screenMargin)

                Spacer()

                VStack(spacing: FledgeTheme.Space.m) {
                    PrimaryActionButton(title: "Let it fly", icon: .fledgeGlyph(), action: fly)
                        .disabled(phase == .flying)
                    Button("Keep it in the nest for now", action: onKeep)
                        .font(.subheadline)
                        .disabled(phase == .flying)
                }
                .padding(.bottom, FledgeTheme.Space.xl)
            }
        }
        .sensoryFeedback(.success, trigger: phase) { _, new in new == .flying }
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.7)) {
                phase = .bird
            }
        }
    }

    private func fly() {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .easeIn(duration: 0.9)) {
            phase = .flying
        }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 1000))
            onFly()
        }
    }
}
