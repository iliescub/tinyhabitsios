import SwiftUI
import HabitCore
import FledgeUI

/// Graduation (docs/DESIGN.md §6.4, v2 in UX-12/13): the bird hops out of the full ring, a recap says why it stuck,
/// and "Let it fly" sends it along the gold path to the Flown shelf. The recap can be shared as an image.
/// Reduce Motion: cross-fades only, no hop or flight. Scrolls at large text sizes.
struct GraduationView: View {
    let habit: Habit
    let day: DayKey
    let onFly: () -> Void
    let onKeep: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .ring
    @State private var shareImage: Image?

    private enum Phase { case ring, bird, flying }

    private var color: Color { FledgeTheme.habitColor(habit.colorKey) }
    private var snapshots: [DaySnapshot] { habit.logs?.compactMap(\.snapshot) ?? [] }
    private var startedOn: DayKey { DayKey(habit.startedAt, dayEndHour: FledgeSettings.dayEndHour) }

    var body: some View {
        let stats = HabitDetailStats(snapshots: snapshots, cadence: habit.cadence, startedOn: startedOn, today: day)
        let recap = RecapModel(
            stats: stats, snapshots: snapshots, startedOn: startedOn, today: day,
            target: habit.target, unit: habit.unit, perWeek: habit.perWeek
        )

        ZStack {
            SkyBackground().ignoresSafeArea()
            FittingScroll {
                VStack(spacing: FledgeTheme.Space.xl) {
                    Spacer(minLength: FledgeTheme.Space.l)
                    hero
                    VStack(spacing: FledgeTheme.Space.xs) {
                        Text("Day \(stats.graduation.daysActive)").fledgeEyebrow()
                        Text("\(habit.name) is ready to fly")
                            .font(FledgeTheme.Typeface.title)
                            .foregroundStyle(FledgeTheme.Palette.ink)
                            .multilineTextAlignment(.center)
                        Text("It stuck. You don't need to watch it anymore.")
                            .font(.subheadline)
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, FledgeTheme.screenMargin)
                    RecapCard(recap: recap, color: color)
                        .padding(.horizontal, FledgeTheme.screenMargin)
                    Spacer(minLength: FledgeTheme.Space.l)
                    actions(recap: recap)
                }
                .frame(maxWidth: NestLayout.readableWidth)
            }
        }
        .sensoryFeedback(.success, trigger: phase) { _, new in new == .flying }
        .sensoryFeedback(.impact(weight: .light), trigger: phase) { _, new in new == .bird }
        .task {
            shareImage = renderShareCard(recap: recap)
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.55, dampingFraction: 0.6)) {
                phase = .bird
            }
        }
    }

    /// The full ring; the bird hops up out of it, then flies off up-left along the dotted path.
    private var hero: some View {
        ZStack {
            if phase != .ring && !reduceMotion {
                FlightPath()
                    .stroke(FledgeTheme.Palette.gold, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 7]))
                    .frame(width: 220, height: 150)
                    .offset(x: -40, y: -50)
                    .opacity(phase == .flying ? 0 : 1)
                    .transition(.opacity)
            }
            HabitRing(fraction: 1, status: .done, color: color, symbol: habit.symbol, size: 150, lineWidth: 14)
                .scaleEffect(phase == .ring ? 1 : 0.62)
                .offset(y: phase == .ring ? 0 : 58)
                .opacity(phase == .ring ? 1 : 0.4)
            if phase != .ring {
                FledgeBird(phase == .flying ? .flying : .sitting, style: .tinted(color))
                    .frame(width: 150)
                    .shadow(color: FledgeTheme.Palette.ink.opacity(0.18), radius: 14, y: 8)
                    .offset(phase == .flying && !reduceMotion ? CGSize(width: -460, height: -720) : CGSize(width: 0, height: -24))
                    .opacity(phase == .flying && reduceMotion ? 0 : 1)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 220)
        .accessibilityHidden(true)
    }

    private func actions(recap: RecapModel) -> some View {
        VStack(spacing: FledgeTheme.Space.m) {
            PrimaryActionButton(title: "Let it fly", icon: .fledgeGlyph(), action: fly)
                .disabled(phase == .flying)
            HStack {
                Button("Keep it in the nest", action: onKeep)
                Spacer()
                if let shareImage {
                    ShareLink(
                        item: shareImage,
                        subject: Text("\(habit.name) stuck"),
                        message: Text("\(habit.name) flew after \(recap.daysText) days with Fledge."),
                        preview: SharePreview("\(habit.name) is ready to fly", image: shareImage)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .font(.subheadline)
            .tint(FledgeTheme.Palette.skyText)
            .disabled(phase == .flying)
            .padding(.horizontal, FledgeTheme.screenMargin + FledgeTheme.Space.s)
        }
        .padding(.bottom, FledgeTheme.Space.l)
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

    /// 1080 × 1920 story image of the recap (UX-13).
    private func renderShareCard(recap: RecapModel) -> Image? {
        let renderer = ImageRenderer(content: ShareRecapCard(name: habit.name, color: color, recap: recap))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 640)
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// Days, rate, best streak and the last 30 days.
struct RecapCard: View {
    let recap: RecapModel
    let color: Color

    var body: some View {
        VStack(spacing: FledgeTheme.Space.m) {
            HStack {
                figure(recap.daysText, "days")
                figure(recap.rateText, "last 30 days")
                figure(recap.bestText, "best streak")
            }
            RecapStrip(days: recap.strip, color: color)
                .frame(height: 14)
            Text(recap.footnote)
                .font(FledgeTheme.Typeface.meta)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
        .padding(FledgeTheme.Space.l)
        .fledgeCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(recap.daysText) days, \(recap.rateText) of the last 30 days, best streak \(recap.bestText) \(recap.bestUnit). \(recap.footnote)"))
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(FledgeTheme.Typeface.metric)
                .foregroundStyle(FledgeTheme.Palette.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 30 thin bars, oldest first: done in the habit colour, rest as an outline, open as hairline.
struct RecapStrip: View {
    let days: [RecapModel.Day]
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(day == .done ? color : day == .rest ? color.opacity(0.15) : FledgeTheme.Palette.hairline)
            }
        }
    }
}

/// The dotted gold curve from the nest up to the upper left.
nonisolated struct FlightPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX * 0.75, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control1: CGPoint(x: rect.maxX * 0.55, y: rect.maxY * 0.55),
            control2: CGPoint(x: rect.maxX * 0.3, y: rect.minY + rect.height * 0.15)
        )
        return path
    }
}

/// The share image (UX-13): a story-sized card with the bird, the numbers and the app name. Fixed light colours,
/// so it looks the same wherever it's posted.
struct ShareRecapCard: View {
    let name: String
    let color: Color
    let recap: RecapModel

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                FlightPath()
                    .stroke(Color(red: 0.82, green: 0.51, blue: 0.05), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 7]))
                    .frame(width: 150, height: 80)
                    .offset(x: 70, y: 12)
                FledgeBird(.flying, style: .tinted(color))
                    .frame(width: 150)
            }
            VStack(spacing: 6) {
                Text("\(name) stuck.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                Text("It flew after \(recap.daysText) days.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .opacity(0.65)
            }
            .foregroundStyle(Color(red: 0.106, green: 0.133, blue: 0.251))
            HStack(spacing: 0) {
                stat(recap.daysText, "days")
                stat(recap.rateText, "last 30 days")
                stat(recap.bestText, "best streak")
            }
            .padding(.vertical, 16)
            .background(.white, in: .rect(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 28)
            RecapStrip(days: recap.strip, color: color)
                .frame(height: 16)
                .padding(.horizontal, 36)
            Spacer()
            HStack(spacing: 8) {
                FledgeBird()
                    .frame(width: 26)
                    .padding(5)
                    .background(Color(red: 0.29, green: 0.53, blue: 1), in: .circle)
                Text("Fledge")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                Text("· 3 habits that track themselves")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .opacity(0.6)
            }
            .foregroundStyle(Color(red: 0.106, green: 0.133, blue: 0.251))
            .padding(.bottom, 30)
        }
        .frame(width: 360, height: 640)
        .background(
            LinearGradient(
                colors: [Color(red: 0.86, green: 0.91, blue: 1), Color(red: 1, green: 0.89, blue: 0.81), Color(red: 0.97, green: 0.96, blue: 0.95)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .environment(\.colorScheme, .light)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded))
            Text(label).font(.system(size: 12, weight: .medium, design: .rounded)).opacity(0.6)
        }
        .foregroundStyle(Color(red: 0.106, green: 0.133, blue: 0.251))
        .frame(maxWidth: .infinity)
    }
}
