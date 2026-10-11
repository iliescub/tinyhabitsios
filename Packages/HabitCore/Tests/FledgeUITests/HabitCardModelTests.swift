import Foundation
import Testing
import HabitCore
@testable import FledgeUI

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private let us = Locale(identifier: "en_US")

private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

private func card(
    source: HabitSourceID = .steps,
    target: Double = 6_000,
    unit: String = "steps",
    started: String = "2026-12-01",
    today: String = "2026-12-15",
    value: Double = 0,
    status: EntryStatus = .pending,
    by: CompletedBy? = nil,
    history: [DaySnapshot] = []
) -> HabitCardModel {
    HabitCardModel(
        name: "Walk", symbol: "figure.walk", colorKey: "dawn", source: source, target: target, unit: unit,
        cadence: .daily, startedOn: key(started), today: key(today), todayValue: value, todayStatus: status,
        todayCompletedBy: by, history: history, locale: us, calendar: utc
    )
}

@Suite("HabitCardModel")
struct HabitCardModelTests {
    @Test func quantityValueText() {
        let model = card(value: 4_210)
        #expect(model.valueText == "4,210 / 6,000 steps")
        #expect(model.isAuto)
        #expect(model.progress.status == .pending)
    }

    @Test func manualOneTimeHabitReadsDoneOrNotYet() {
        #expect(card(source: .manual, target: 1, unit: "times").valueText == "Not yet")
        #expect(card(source: .manual, target: 1, unit: "times", status: .done, by: .manual).valueText == "Done")
    }

    @Test func restDayText() {
        #expect(card(status: .skipped).valueText == "Rest day")
    }

    @Test func countdownBeforeMinimumDays() {
        // Started Dec 1, today Dec 15 → day 15 of the 30-day minimum.
        let model = card()
        #expect(model.flightText == "15 days until it can fly")
        #expect(!model.isReadyToFly)
    }

    @Test func readyToFlyAfterThirtyStrongDays() {
        let history = (0..<30).map { DaySnapshot(day: key("2026-12-01").adding(days: $0, calendar: utc), status: .done) }
        let model = card(today: "2026-12-30", history: history)
        #expect(model.isReadyToFly)
        #expect(model.flightText == "Ready to fly")
    }
}

@Suite("TodaySummary")
struct TodaySummaryTests {
    @Test func emptyNest() {
        #expect(TodaySummary.text(for: []) == "Your nest is empty. Add up to three habits.")
    }

    @Test func nothingDone() {
        #expect(TodaySummary.text(for: [card(), card(), card()]) == "Three in the nest.")
    }

    @Test func partlyDone() {
        let done = card(value: 6_500)
        #expect(TodaySummary.text(for: [done, card(), card()]) == "1 of 3 done.")
    }

    @Test func allDone() {
        let done = card(value: 6_500)
        #expect(TodaySummary.text(for: [done, done]) == "All 2 done. Nest is quiet.")
    }

    @Test func restOnlyRemaining() {
        let done = card(value: 6_500)
        #expect(TodaySummary.text(for: [done, card(status: .skipped)]) == "Rest day for Walk.")
    }
}
