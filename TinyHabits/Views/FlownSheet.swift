import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// The Flown shelf (docs/DESIGN.md §6.5, v2 in UX-14): every graduate as its own fledgling, with how well it's
/// holding up on its own over the last 14 days. Tap one to bring it back to the nest.
struct FlownSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var flown: [Habit]
    @Query private var active: [Habit]
    @State private var errorMessage: String?
    @State private var bringingBack: Habit?

    init() {
        let graduated = HabitState.graduated.rawValue
        _flown = Query(filter: #Predicate<Habit> { $0.stateRaw == graduated })
        let activeState = HabitState.active.rawValue
        _active = Query(filter: #Predicate<Habit> { $0.stateRaw == activeState })
    }

    private var sorted: [Habit] {
        flown.sorted { ($0.graduatedAt ?? .distantPast) > ($1.graduatedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if flown.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("Nothing has flown yet")
                        } icon: {
                            FledgeBird(.sleeping, style: .glyph)
                                .foregroundStyle(FledgeTheme.Palette.ink2)
                                .frame(width: 72)
                        }
                    } description: {
                        Text("A habit can fly from day \(GraduationRule.standard.minDays), once it's met on most days. It lands here and keeps tracking quietly.")
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
                            header
                            VStack(spacing: FledgeTheme.Space.m) {
                                ForEach(sorted) { habit in
                                    Button { bringingBack = habit } label: {
                                        FlownRow(habit: habit, today: today)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Bring back to the nest")
                                }
                            }
                            footer
                        }
                        .padding(FledgeTheme.screenMargin)
                    }
                }
            }
            .background(SkyBackground().ignoresSafeArea())
            .navigationTitle("Flown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Bring \(bringingBack?.name ?? "it") back to the nest?",
                isPresented: Binding(get: { bringingBack != nil }, set: { if !$0 { bringingBack = nil } }),
                titleVisibility: .visible,
                presenting: bringingBack
            ) { habit in
                Button("Bring back") { bringBack(habit) }
            } message: { _ in
                Text(active.count >= SlotPolicy.maxActive
                     ? "Your nest is full. Let one fly or pause one first."
                     : "It takes a free slot and keeps its history.")
            }
            .alert("Couldn't bring it back", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var today: DayKey { DayKey.today() }

    private var header: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
            Text(flown.count == 1 ? "1 habit flew" : "\(flown.count) habits flew")
                .font(FledgeTheme.Typeface.title)
                .foregroundStyle(FledgeTheme.Palette.ink)
            Text("They keep tracking quietly. We'll nudge you only if one slips.")
                .font(.subheadline)
                .foregroundStyle(FledgeTheme.Palette.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var footer: some View {
        let free = max(0, SlotPolicy.maxActive - active.count)
        return VStack(spacing: FledgeTheme.Space.s) {
            FledgeBird(.peeking, style: .glyph)
                .foregroundStyle(FledgeTheme.Palette.ink2.opacity(0.35))
                .frame(width: 70)
            Text(free == 0 ? "The nest is full." : free == 1 ? "The nest has room for one more." : "The nest has room for \(free) more.")
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FledgeTheme.Space.xl)
    }

    private func bringBack(_ habit: Habit) {
        do {
            try context.resume(habitID: habit.id)
            AppRefresh.afterWrite(context: context, structural: true)
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one first."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// One graduate: its bird, when it flew, and the 14-day holding trend (Health habits only; tap-to-log
/// graduates aren't logged any more, so they have nothing to judge).
struct FlownRow: View {
    let habit: Habit
    let today: DayKey
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var color: Color { FledgeTheme.habitColor(habit.colorKey) }
    private var snapshots: [DaySnapshot] { habit.logs?.compactMap(\.snapshot) ?? [] }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FledgeTheme.Space.s))
            : AnyLayout(HStackLayout(spacing: FledgeTheme.Space.m))
        layout {
            FledgeBird(style: .tinted(color))
                .frame(width: 44, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                Text(flewText)
                    .font(.footnote)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            holding
        }
        .padding(FledgeTheme.Space.l)
        .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var holding: some View {
        let since = habit.graduatedAt.map { DayKey($0, dayEndHour: FledgeSettings.dayEndHour) }
        if habit.source.isAuto, let rate = HoldingRate.rate(snapshots: snapshots, today: today, since: since) {
            let strong = rate >= HoldingRate.strong
            VStack(alignment: .trailing, spacing: 2) {
                Sparkline(values: HoldingRate.trend(snapshots: snapshots, today: today))
                    .stroke(strong ? FledgeTheme.Palette.gold : FledgeTheme.Palette.ink2, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 56, height: 22)
                    .accessibilityHidden(true)
                Text("\(Int((rate * 100).rounded()))% holding")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(strong ? FledgeTheme.Palette.ink : FledgeTheme.Palette.ink2)
            }
        } else if !habit.source.isAuto {
            Text("On its own")
                .font(FledgeTheme.Typeface.meta)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
    }

    private var flewText: String {
        guard let graduatedAt = habit.graduatedAt else { return "Flown" }
        let days = DayKey(habit.startedAt).days(to: DayKey(graduatedAt)) + 1
        return "Flew \(graduatedAt.formatted(.dateTime.day().month(.abbreviated))) · after \(days) days"
    }
}

/// A line through 0…1 values, left to right.
nonisolated struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let step = rect.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: rect.minX + CGFloat(index) * step, y: rect.maxY - CGFloat(min(max(value, 0), 1)) * rect.height)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}
