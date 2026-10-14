import Foundation
import Testing
import HabitCore
@testable import FledgeUI

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2
    return calendar
}()

private let gb = Locale(identifier: "en_GB")
private let us = Locale(identifier: "en_US")

private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

private func card(
    name: String = "Walk", source: HabitSourceID = .steps, target: Double = 6_000, unit: String = "steps",
    value: Double = 0, status: EntryStatus = .pending, by: CompletedBy? = nil
) -> HabitCardModel {
    HabitCardModel(
        name: name, symbol: "figure.walk", colorKey: "dawn", source: source, target: target, unit: unit,
        cadence: .daily, startedOn: key("2026-12-01"), today: key("2026-12-15"), todayValue: value, todayStatus: status,
        todayCompletedBy: by, history: [], locale: us, calendar: utc
    )
}

@Suite("Card value parts and freshness")
struct CardPartsTests {
    @Test func quantitySplitsIntoMetricAndGoal() {
        let model = card(value: 4_210)
        #expect(model.metricText == "4,210")
        #expect(model.goalText == "/ 6,000 steps")
    }

    @Test func oneTimeAndRestHaveNoGoal() {
        let read = card(name: "Read", source: .manual, target: 1, unit: "times", status: .done, by: .manual)
        #expect(read.metricText == "Done")
        #expect(read.goalText == nil)
        #expect(card(status: .skipped).metricText == "Rest day")
        #expect(card(status: .skipped).goalText == nil)
    }

    @Test func freshnessText() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(HabitCardModel.freshness(lastUpdated: nil, now: now) == nil)
        #expect(HabitCardModel.freshness(lastUpdated: now.addingTimeInterval(-20), now: now) == "just now")
        #expect(HabitCardModel.freshness(lastUpdated: now.addingTimeInterval(-4 * 60), now: now) == "4 min ago")
        #expect(HabitCardModel.freshness(lastUpdated: now.addingTimeInterval(-2 * 3_600 - 5), now: now) == "2 h ago")
        #expect(HabitCardModel.freshness(lastUpdated: now.addingTimeInterval(-90_000), now: now) == "over a day ago")
    }
}

@Suite("Today header")
struct TodayHeaderTests {
    @Test func titles() {
        let done = card(value: 6_500)
        let rest = card(status: .skipped)
        #expect(TodaySummary.title(for: []) == "An empty nest")
        #expect(TodaySummary.title(for: [card(), card(), card()]) == "Three in the nest")
        #expect(TodaySummary.title(for: [done, card(), card()]) == "1 of 3 done")
        #expect(TodaySummary.title(for: [done, done, done]) == "All three done")
        #expect(TodaySummary.title(for: [done]) == "Done for today")
        #expect(TodaySummary.title(for: [rest, rest]) == "Rest day")
        #expect(TodaySummary.title(for: [done, rest]) == "1 of 2 done")
    }

    @Test func detailNamesTheClosestHabit() {
        let walk = card(value: 4_210)
        let water = card(name: "Water", source: .water, target: 2, unit: "L", value: 0.5)
        #expect(TodaySummary.detail(for: [walk, water], locale: us) == "Walk is 1,790 steps away.")
        let read = card(name: "Read", source: .manual, target: 1, unit: "times")
        #expect(TodaySummary.detail(for: [read], locale: us) == "Read is still to do.")
    }

    @Test func detailWhenNothingIsPending() {
        let done = card(value: 6_500)
        let rest = card(name: "Meditate", status: .skipped)
        #expect(TodaySummary.detail(for: [done, done], locale: us) == "Nest is quiet.")
        #expect(TodaySummary.detail(for: [done, rest], locale: us) == "Rest day for Meditate.")
        #expect(TodaySummary.detail(for: [], locale: us) == "Add up to three habits.")
    }
}

@Suite("WeekModel")
struct WeekModelTests {
    @Test func lastSevenDaysEndingToday() {
        let model = WeekModel(habits: [], today: key("2026-12-16"), calendar: utc, locale: gb)
        #expect(model.days.count == 7)
        #expect(model.days.first?.day == key("2026-12-10"))
        #expect(model.days.last?.isToday == true)
        #expect(model.days.last?.label == "W")   // Wednesday
    }

    @Test func dotsPerHabit() {
        let walk = WeekModel.Habit(colorKey: "dawn", startedOn: key("2026-12-01"), snapshots: [
            DaySnapshot(day: key("2026-12-15"), status: .done),
            DaySnapshot(day: key("2026-12-14"), status: .skipped),
        ])
        let read = WeekModel.Habit(colorKey: "sky", startedOn: key("2026-12-15"), snapshots: [
            DaySnapshot(day: key("2026-12-15"), status: .done),
        ])
        let model = WeekModel(habits: [walk, read], today: key("2026-12-16"), calendar: utc, locale: gb)
        let yesterday = model.days[5]
        #expect(yesterday.dots.map(\.state) == [.done, .done])
        #expect(yesterday.accessibilityLabel == "Tuesday: 2 of 2 done")
        let monday = model.days[4]
        #expect(monday.dots.map(\.state) == [.rest, .none])
        #expect(monday.accessibilityLabel == "Monday: 0 of 1 done, 1 rest day")
        #expect(model.days[6].dots.map(\.state) == [.open, .open])
        #expect(model.days[6].accessibilityLabel.hasPrefix("Today: "))
    }
}

@Suite("JourneyModel")
struct JourneyModelTests {
    private func stats(days: Int, doneEvery: Int = 1) -> HabitDetailStats {
        let start = key("2026-11-01")
        let today = start.adding(days: days - 1, calendar: utc)
        let snapshots = (0..<days).compactMap { offset -> DaySnapshot? in
            offset % doneEvery == 0 ? DaySnapshot(day: start.adding(days: offset, calendar: utc), status: .done) : nil
        }
        return HabitDetailStats(snapshots: snapshots, cadence: .daily, startedOn: start, today: today, calendar: utc)
    }

    @Test func earlyDaysCountDownToTheGate() {
        let model = JourneyModel(stats: stats(days: 12), startedOn: key("2026-11-01"), locale: gb, calendar: utc)
        #expect(model.status == "18 days until it can fly.")
        #expect(model.headline.hasPrefix("Day 12 · "))
        #expect(model.milestones.map(\.title) == ["Day 1", "Day 30", "Day 66"])
        #expect(model.milestones[0].subtitle == "1 Nov")
        #expect(model.milestones[1].isGate)
        #expect(!model.milestones[1].isReached)
        #expect(abs(model.progress - 12.0 / 66) < 0.0001)
    }

    @Test func readyAfterAStrongMonth() {
        let model = JourneyModel(stats: stats(days: 40), startedOn: key("2026-11-01"), locale: gb, calendar: utc)
        #expect(model.status == "Ready whenever you are.")
        #expect(model.milestones[1].isReached)
    }

    @Test func pastTheGateButBelowTheThreshold() {
        let model = JourneyModel(stats: stats(days: 40, doneEvery: 2), startedOn: key("2026-11-01"), locale: gb, calendar: utc)
        #expect(model.status == "Needs 80% of the last 30 days to fly.")
    }
}

@Suite("Heatmap labels and Flown preview")
struct HeatmapLabelTests {
    @Test func monthAndWeekdayLabels() {
        let model = HeatmapModel(snapshots: [], startedOn: key("2026-09-01"), today: key("2026-12-16"), calendar: utc, locale: gb)
        #expect(model.weekdayLabels == ["M", "", "W", "", "F", "", ""])
        #expect(model.monthLabels.map(\.text).suffix(3) == ["Oct", "Nov", "Dec"])
        #expect(model.monthLabels.allSatisfy { (0..<12).contains($0.week) })
    }

    @Test func flownPreviewText() {
        let date = DayKey(rawValue: "2026-09-30")!.date(in: utc)
        #expect(FlownPreview.text(latestName: nil, flewOn: nil, days: nil, total: 0) == "Habits that stick can fly from day 30.")
        #expect(FlownPreview.text(latestName: "Stretch", flewOn: date, days: 67, total: 1, locale: gb) == "Stretch flew on 30 Sep after 67 days.")
        #expect(FlownPreview.text(latestName: "Stretch", flewOn: date, days: 67, total: 3) == "Stretch and 2 more have flown.")
    }
}

@Suite("TemplateStyle")
struct TemplateStyleTests {
    private let walk = Pack.Template(name: "Walk", symbol: "figure.walk", source: .steps, target: 6_000, unit: "steps")
    private let workout = Pack.Template(name: "Work out", symbol: "dumbbell.fill", source: .workout, target: 1, unit: "workout", perWeek: 3)
    private let read = Pack.Template(name: "Read", symbol: "book.fill", source: .manual, target: 1, unit: "times")

    @Test func healthSourcesHaveFixedColours() {
        #expect(TemplateStyle.colorKey(for: walk) == "dawn")
        #expect(TemplateStyle.colorKey(for: workout) == "teal")
        #expect(FledgeTheme.habitColorKeys.contains(TemplateStyle.colorKey(for: read)))
        #expect(TemplateStyle.colorKey(for: read) == TemplateStyle.colorKey(for: read))   // stable
    }

    @Test func preferredColourAvoidsColoursInTheNest() {
        #expect(TemplateStyle.preferredColorKey(for: walk, taken: [], slot: 1) == "dawn")
        #expect(TemplateStyle.preferredColorKey(for: walk, taken: ["dawn"], slot: 1) == "sky")
        #expect(TemplateStyle.preferredColorKey(for: walk, taken: ["dawn", "sky"], slot: 1) == "meadow")
    }

    @Test func targetText() {
        #expect(TemplateStyle.targetText(for: walk, locale: Locale(identifier: "en_US")) == "6,000 steps a day")
        #expect(TemplateStyle.targetText(for: workout) == "1 workout · 3× a week")
        #expect(TemplateStyle.targetText(for: read) == "Once a day")
    }
}

@Suite("RecapModel")
struct RecapModelTests {
    @Test func recapNumbersAndStrip() {
        let start = key("2026-11-01")
        let today = start.adding(days: 39, calendar: utc)
        let snapshots = (0..<40).map { offset in
            DaySnapshot(day: start.adding(days: offset, calendar: utc), status: offset == 35 ? .skipped : .done)
        }
        let stats = HabitDetailStats(snapshots: snapshots, cadence: .daily, startedOn: start, today: today, calendar: utc)
        let recap = RecapModel(
            stats: stats, snapshots: snapshots, startedOn: start, today: today,
            target: 6_000, unit: "steps", perWeek: 7, locale: Locale(identifier: "en_GB"), calendar: utc
        )
        #expect(recap.daysText == "40")
        #expect(recap.rateText == "100%")
        #expect(recap.bestUnit == "days")
        #expect(recap.footnote == "Started 1 Nov · 6,000 steps a day")
        #expect(recap.strip.count == 30)
        #expect(recap.strip.last == .done)
        #expect(recap.strip[30 - 1 - 4] == .rest)   // day 35 of 40 = 4 days before today
    }
}

@Suite("NestLayout")
struct NestLayoutTests {
    @Test func splitsOnlyWhenWideAndNotAtAccessibilitySizes() {
        #expect(!NestLayout.isSplit(width: 402, isAccessibilitySize: false))     // iPhone
        #expect(!NestLayout.isSplit(width: 507, isAccessibilitySize: false))     // iPad narrow window
        #expect(NestLayout.isSplit(width: 834, isAccessibilitySize: false))      // iPad portrait
        #expect(!NestLayout.isSplit(width: 1376, isAccessibilitySize: true))     // AX sizes keep one column
    }

    @Test func nestColumnStaysBetween360And420() {
        #expect(NestLayout.nestColumnWidth(for: 700) == 360)
        #expect(NestLayout.nestColumnWidth(for: 920) == 386.4)
        #expect(NestLayout.nestColumnWidth(for: 1376) == 420)
    }
}

@Suite("Head start and forecast in the UI models")
struct DifferentiatorModelTests {
    @Test func heatmapShowsDaysBeforeFledgeAsEarlier() {
        let history = [DaySnapshot(day: key("2026-12-05"), status: .done), DaySnapshot(day: key("2026-12-06"), status: .pending)]
        let model = HeatmapModel(snapshots: history, startedOn: key("2026-12-10"), today: key("2026-12-16"), calendar: utc)
        let cells = Dictionary(uniqueKeysWithValues: model.weeks.flatMap { $0 }.map { ($0.day, $0.state) })
        #expect(cells[key("2026-12-05")] == .earlier)
        #expect(cells[key("2026-12-06")] == .beforeStart)
        #expect(model.hasEarlierDays)
    }

    @Test func forecastLine() {
        let start = key("2026-11-01")
        let today = start.adding(days: 11, calendar: utc)
        let snapshots = (0..<12).map { DaySnapshot(day: start.adding(days: $0, calendar: utc), status: .done) }
        let stats = HabitDetailStats(snapshots: snapshots, cadence: .daily, startedOn: start, today: today, calendar: utc)
        let fly = FlightForecast.flyDate(snapshots: snapshots, cadence: .daily, startedOn: start, today: today, calendar: utc)
        let model = JourneyModel(stats: stats, startedOn: start, flyDate: fly, locale: gb, calendar: utc)
        #expect(model.forecast == "On track to fly around 30 Nov.")

        let patchy = snapshots.enumerated().filter { $0.offset % 3 == 0 }.map(\.element)
        let patchyStats = HabitDetailStats(snapshots: patchy, cadence: .daily, startedOn: start, today: today, calendar: utc)
        let later = FlightForecast.flyDate(snapshots: patchy, cadence: .daily, startedOn: start, today: today, calendar: utc)
        let patchyModel = JourneyModel(stats: patchyStats, startedOn: start, flyDate: later, locale: gb, calendar: utc)
        #expect(patchyModel.forecast?.hasPrefix("Keep it going and it can fly around") == true)
    }
}
