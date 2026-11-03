import Foundation
import SwiftUI
import Testing
import HabitCore
@testable import FledgeUI

// Renders every shared view in each of its states, light and dark, and checks that something was drawn.
// These run the view bodies the widgets and the app use, so a crash or an empty layout fails here first.

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2
    return calendar
}()

private let us = Locale(identifier: "en_US")
private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

private func card(
    _ name: String, source: HabitSourceID = .steps, target: Double = 6_000, unit: String = "steps",
    value: Double = 0, status: EntryStatus = .pending, history: [DaySnapshot] = [], startedOn: String = "2026-12-01"
) -> HabitCardModel {
    HabitCardModel(
        name: name, symbol: "figure.walk", colorKey: "dawn", source: source, target: target, unit: unit,
        cadence: .daily, startedOn: key(startedOn), today: key("2027-01-20"), todayValue: value, todayStatus: status,
        todayCompletedBy: status == .done ? .manual : nil, history: history, locale: us, calendar: utc
    )
}

private func strongHistory() -> [DaySnapshot] {
    (1...45).map { DaySnapshot(day: key("2027-01-20").adding(days: -$0, calendar: utc), status: .done) }
}

private let items: [NestSnapshot.Item] = [
    .init(id: UUID(), card: card("Walk", value: 4_210, history: strongHistory()), lastUpdated: Date(timeIntervalSince1970: 1_800_000_000)),
    .init(id: UUID(), card: card("Read", source: .manual, target: 1, unit: "times", status: .done), lastUpdated: nil),
    .init(id: UUID(), card: card("Meditate", source: .mindfulMinutes, target: 5, unit: "min", status: .skipped), lastUpdated: nil),
]

@MainActor
private func render(_ view: some View, width: CGFloat = 360, height: CGFloat = 360, scheme: ColorScheme = .light) -> Bool {
    let renderer = ImageRenderer(content: view.frame(width: width, height: height).environment(\.colorScheme, scheme))
    renderer.scale = 1
    guard let image = renderer.cgImage else { return false }
    return image.width == Int(width) && image.height == Int(height)
}

@Suite("Render: widgets")
@MainActor
struct WidgetRenderTests {
    private func content(_ family: NestWidgetContent<HabitRing>.Family, snapshot: NestSnapshot, isPro: Bool) -> some View {
        NestWidgetContent(family: family, snapshot: snapshot, date: Date(timeIntervalSince1970: 1_800_000_100), isPro: isPro) { item, size, line in
            HabitRing(fraction: item.card.progress.fraction, status: item.card.progress.status,
                      color: FledgeTheme.habitColor(item.card.colorKey), symbol: item.card.symbol, size: size, lineWidth: line)
        }
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func everyFamilyRenders(scheme: ColorScheme) {
        let snapshot = NestSnapshot(day: key("2027-01-20"), items: items, locale: us)
        for family in [NestWidgetContent<HabitRing>.Family.small, .medium, .large, .extraLarge] {
            #expect(render(content(family, snapshot: snapshot, isPro: true), width: 720, height: 340, scheme: scheme))
            #expect(render(content(family, snapshot: snapshot, isPro: false), width: 720, height: 340, scheme: scheme))
        }
        let one = NestSnapshot(day: key("2027-01-20"), items: Array(items.prefix(1)), locale: us)
        #expect(render(content(.large, snapshot: one, isPro: true), width: 360, height: 380, scheme: scheme))
        #expect(render(content(.medium, snapshot: .placeholder, isPro: true), scheme: scheme))
    }

    @Test func standaloneWidgetPieces() {
        let snapshot = NestSnapshot(day: key("2027-01-20"), items: items, locale: us)
        #expect(render(FreshnessLine(snapshot: snapshot, now: Date(timeIntervalSince1970: 1_800_000_600))))
        #expect(render(FreshnessLine(snapshot: .placeholder, now: .now)))
        #expect(render(ProWidget()))
        #expect(render(EmptyNestWidget()))
        #expect(render(NestWidgetBackground(), scheme: .dark))
    }
}

@Suite("Render: components")
@MainActor
struct ComponentRenderTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func ringsInEveryState(scheme: ColorScheme) {
        let states: [(Double, EntryStatus, HabitRing.Badge?)] = [
            (0, .pending, nil), (0.4, .pending, .health), (1, .done, nil), (0, .skipped, nil), (1.2, .done, .health),
        ]
        for (fraction, status, badge) in states {
            for size: CGFloat in [28, 64, 160] {
                let ring = HabitRing(fraction: fraction, status: status, color: FledgeTheme.Palette.sky, symbol: "book.fill",
                                     size: size, lineWidth: size / 8, idleBadge: badge)
                #expect(render(ring, width: 180, height: 180, scheme: scheme))
            }
        }
    }

    @Test func nestPieces() {
        let rings = [
            NestGlyph.Ring(fraction: 1, status: .done, color: .red),
            NestGlyph.Ring(fraction: 0.3, status: .pending, color: .blue),
            NestGlyph.Ring(fraction: 0, status: .skipped, color: .green),
        ]
        #expect(render(NestGlyph(rings: rings), width: 60, height: 60))
        #expect(render(NestGlyph(rings: []), width: 60, height: 60))
        let week = WeekModel(habits: [WeekModel.Habit(colorKey: "dawn", startedOn: key("2027-01-01"), snapshots: strongHistory())],
                             today: key("2027-01-20"), calendar: utc, locale: us)
        #expect(render(WeekStrip(model: week), width: 360, height: 90))
        #expect(render(WeekStrip(model: week).environment(\.dynamicTypeSize, .accessibility3), width: 360, height: 140))
        let stats = HabitDetailStats(snapshots: strongHistory(), cadence: .daily, startedOn: key("2026-12-05"), today: key("2027-01-20"), calendar: utc)
        let journey = JourneyModel(stats: stats, startedOn: key("2026-12-05"), flyDate: key("2027-01-25"), locale: us, calendar: utc)
        #expect(render(JourneyTrack(model: journey, color: .orange), width: 360, height: 120))
        let early = HabitDetailStats(snapshots: [], cadence: .daily, startedOn: key("2027-01-18"), today: key("2027-01-20"), calendar: utc)
        #expect(render(JourneyTrack(model: JourneyModel(stats: early, startedOn: key("2027-01-18"), locale: us, calendar: utc), color: .orange), width: 360, height: 120))
        #expect(render(FeatherBurst(trigger: 1, color: .orange)))
        #expect(render(FeatherBurst(trigger: 0, color: .orange)))
        #expect(render(IconSquare(symbol: "book.fill", color: .blue)))
        #expect(render(IconSquare(symbol: "book.fill", color: .blue, size: 50, filled: true)))
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func themeSurfacesAndBirds(scheme: ColorScheme) {
        #expect(render(Text("Card").fledgeCard(), scheme: scheme))
        #expect(render(Text("Tinted").fledgeCard(cornerRadius: 18, tint: FledgeTheme.Palette.gold), scheme: scheme))
        #expect(render(Text("Eyebrow").fledgeEyebrow(), scheme: scheme))
        #expect(render(Button("Go") {}.buttonStyle(FledgePrimaryButtonStyle()), scheme: scheme))
        #expect(render(Button("Off") {}.buttonStyle(FledgePrimaryButtonStyle()).disabled(true), scheme: scheme))
        for hour in [5, 9, 13, 18, 22] {
            let date = utc.date(from: DateComponents(year: 2027, month: 1, day: 20, hour: hour))!
            #expect(render(SkyBackground(date: date), scheme: scheme))
        }
        for pose in FledgeBirdGeometry.Pose.allCases {
            #expect(render(FledgeBird(pose), width: 120, height: 120, scheme: scheme))
            #expect(render(FledgeBird(pose, style: .glyph), width: 120, height: 120, scheme: scheme))
            #expect(render(FledgeBird(pose, style: .tinted(.purple)), width: 120, height: 120, scheme: scheme))
            #expect(render(FledgeGlyphShape(pose).fill(.black), width: 40, height: 40, scheme: scheme))
        }
        for key in FledgeTheme.habitColorKeys + ["unknown"] {
            #expect(!FledgeTheme.habitColorName(key).isEmpty)
            #expect(render(Rectangle().fill(FledgeTheme.habitColor(key)), width: 10, height: 10, scheme: scheme))
        }
        #expect(FledgeTheme.defaultColorKey(forSlot: 0) == "dawn")
        #expect(FledgeTheme.defaultColorKey(forSlot: 9) == "sky")
    }

    @Test func resolutionStripStates() {
        let dots: [YearMap.Dot] = [.before, .full, .partial, .empty, .future]
        #expect(render(YearStrip(dots: Array(repeating: dots, count: 73).flatMap { $0 }), width: 300, height: 20))
        #expect(render(YearStrip(dots: []), width: 300, height: 20))
        #expect(render(YearStrip(dots: dots, color: FledgeTheme.Palette.gold), width: 300, height: 20, scheme: .dark))
    }
}

@Suite("Render: remaining widget states and model text")
@MainActor
struct RemainingStateTests {
    @Test func quietNestAndStaleHealthLine() {
        let done = [
            NestSnapshot.Item(id: UUID(), card: card("Read", source: .manual, target: 1, unit: "times", status: .done), lastUpdated: nil),
            NestSnapshot.Item(id: UUID(), card: card("Walk", value: 7_000, status: .done), lastUpdated: Date(timeIntervalSince1970: 1_800_000_000)),
        ]
        let snapshot = NestSnapshot(day: key("2027-01-20"), items: done, locale: us)
        let large = NestWidgetContent(family: .large, snapshot: snapshot, date: Date(timeIntervalSince1970: 1_800_000_100), isPro: true) { _, _, _ in
            Color.clear
        }
        #expect(render(large, width: 360, height: 380))
        // Health data two hours old shows the freshness line.
        let stale = NestSnapshot(day: key("2027-01-20"), items: items, locale: us)
        #expect(stale.oldestHealthUpdate != nil)
        #expect(render(FreshnessLine(snapshot: stale, now: Date(timeIntervalSince1970: 1_800_007_200))))
    }

    @Test func detailAndCardTexts() {
        let daily = HabitDetailStats(snapshots: strongHistory(), cadence: .daily, startedOn: key("2026-12-05"), today: key("2027-01-20"), calendar: utc)
        #expect(daily.bestText == "45 days")
        let one = HabitDetailStats(snapshots: [DaySnapshot(day: key("2027-01-19"), status: .done)], cadence: .daily,
                                   startedOn: key("2027-01-19"), today: key("2027-01-20"), calendar: utc)
        #expect(one.bestText == "1 day")
        let weekly = HabitDetailStats(snapshots: [], cadence: Cadence(perWeek: 3), startedOn: key("2027-01-18"), today: key("2027-01-20"), calendar: utc)
        #expect(weekly.bestText == "0 weeks")

        let pages = card("Read", source: .manual, target: 20, unit: "pages", value: 5)
        #expect(pages.isManualQuantity)
        #expect(pages.incrementText == "+5 pages")
        #expect(!card("Walk").isManualQuantity)

        let heat = HeatmapModel(snapshots: strongHistory(), startedOn: key("2026-12-05"), today: key("2027-01-20"), calendar: utc)
        #expect(heat.weeks.flatMap { $0 }.allSatisfy { !$0.id.isEmpty })
    }
}
