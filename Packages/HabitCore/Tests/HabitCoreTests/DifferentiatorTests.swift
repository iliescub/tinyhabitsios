import Foundation
import Testing
@testable import HabitCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

@Suite("HealthBaseline (head start)")
struct HealthBaselineTests {
    private func baseline(_ values: [Double], target: Double = 6_000) -> HealthBaseline {
        HealthBaseline(values: values, target: target, step: 500, range: 500...50_000)
    }

    @Test func notEnoughDataGivesNoAdvice() {
        let model = baseline(Array(repeating: 0, count: 25) + [8_000, 8_000, 8_000, 8_000, 8_000])
        #expect(model.verdict == .notEnoughData)
        #expect(model.suggestedTarget == nil)
    }

    @Test func alreadyAHabitSuggestsABiggerGoal() {
        let model = baseline(Array(repeating: 9_000, count: 26) + Array(repeating: 4_000, count: 4))
        #expect(model.daysMet == 26)
        #expect(model.verdict == .alreadyHabit)
        #expect(model.suggestedTarget == 10_000)   // average 8,333 × 1.2 = 10,000
    }

    @Test func withinReachKeepsTheGoal() {
        let model = baseline(Array(repeating: 6_500, count: 18) + Array(repeating: 4_000, count: 12))
        #expect(model.verdict == .withinReach)
        #expect(model.suggestedTarget == nil)
    }

    @Test func farAwayStartsSmaller() {
        let model = baseline(Array(repeating: 4_000, count: 28) + [7_000, 7_000])
        #expect(model.verdict == .startSmaller)
        #expect(abs(model.average - 4_200) < 0.01)
        #expect(model.suggestedTarget == 4_500)    // 4,200 × 1.1 = 4,620 → nearest 500: 4,500
    }

    @Test func smallerGoalNeverRoundsBackToTheOldOne() {
        // Average 5,030: 5,533 rounded up would be 6,000 again; the nearest step gives 5,500.
        let model = baseline(Array(repeating: 5_030, count: 30))
        #expect(model.verdict == .startSmaller)
        #expect(model.suggestedTarget == 5_500)
    }

    @Test func zeroDaysAreNotAveraged() {
        let model = baseline(Array(repeating: 0, count: 10) + Array(repeating: 5_000, count: 20))
        #expect(model.daysWithData == 20)
        #expect(model.average == 5_000)
    }
}

@Suite("SlipCheck")
struct SlipCheckTests {
    @Test func nudgesOnceBelowHalfAndRearmsAtEightyPercent() {
        #expect(SlipCheck.decide(rate: 0.4, alreadyNudged: false) == .nudge)
        #expect(SlipCheck.decide(rate: 0.4, alreadyNudged: true) == .none)
        #expect(SlipCheck.decide(rate: 0.7, alreadyNudged: true) == .none)
        #expect(SlipCheck.decide(rate: 0.85, alreadyNudged: true) == .rearm)
        #expect(SlipCheck.decide(rate: 0.9, alreadyNudged: false) == .none)
        #expect(SlipCheck.decide(rate: nil, alreadyNudged: false) == .none)
    }

    @Test func nudgeArrivesAtAPoliteHour() {
        let id = UUID()
        let afternoon = ISO8601DateFormatter().date(from: "2026-12-15T14:00:00Z")!
        #expect(ReminderPlan.slipNudge(habitID: id, name: "Walk", now: afternoon, calendar: utc).fireDate == afternoon.addingTimeInterval(3_600))
        let lateEvening = ISO8601DateFormatter().date(from: "2026-12-15T22:30:00Z")!
        let fire = ReminderPlan.slipNudge(habitID: id, name: "Walk", now: lateEvening, calendar: utc).fireDate
        #expect(fire == ISO8601DateFormatter().date(from: "2026-12-16T10:00:00Z"))
        let early = ISO8601DateFormatter().date(from: "2026-12-15T06:00:00Z")!
        #expect(ReminderPlan.slipNudge(habitID: id, name: "Walk", now: early, calendar: utc).fireDate == ISO8601DateFormatter().date(from: "2026-12-15T10:00:00Z"))
        #expect(ReminderPlan.slipNudge(habitID: id, name: "Walk", now: early, calendar: utc).identifier.hasPrefix(ReminderPlan.slipIdentifierPrefix))
    }
}

@Suite("FlightForecast")
struct FlightForecastTests {
    let start = key("2026-11-01")

    private func done(_ days: Range<Int>) -> [DaySnapshot] {
        days.map { DaySnapshot(day: start.adding(days: $0, calendar: utc), status: .done) }
    }

    @Test func onTrackFliesOnDayThirty() {
        let today = start.adding(days: 11, calendar: utc)      // day 12, every day done
        let date = FlightForecast.flyDate(snapshots: done(0..<12), cadence: .daily, startedOn: start, today: today, calendar: utc)
        #expect(date == start.adding(days: 29, calendar: utc)) // day 30
    }

    @Test func missedDaysPushTheDateBack() {
        let today = start.adding(days: 11, calendar: utc)
        // 4 of 12: even with every day done from now, day 30 is only 22/30 (< 80%), so it flies later.
        let patchy = done(0..<12).enumerated().filter { $0.offset % 3 == 0 }.map(\.element)
        let date = FlightForecast.flyDate(snapshots: patchy, cadence: .daily, startedOn: start, today: today, calendar: utc)
        #expect(date != nil)
        #expect(date! > start.adding(days: 29, calendar: utc))
    }

    @Test func readyHabitsHaveNoForecast() {
        let today = start.adding(days: 39, calendar: utc)
        #expect(FlightForecast.flyDate(snapshots: done(0..<40), cadence: .daily, startedOn: start, today: today, calendar: utc) == nil)
    }
}
