import Foundation
import Testing
import HabitCore
@testable import FledgeUI

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2 // Monday
    return calendar
}()

private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

@Suite("HeatmapModel")
struct HeatmapModelTests {
    @Test func twelveWeeksEndingThisWeek() {
        let model = HeatmapModel(snapshots: [], startedOn: key("2026-10-01"), today: key("2026-12-16"), calendar: utc)
        #expect(model.weeks.count == 12)
        #expect(model.weeks.allSatisfy { $0.count == 7 })
        let last = model.weeks.last!
        #expect(last.first?.day == key("2026-12-14")) // Monday of this week
        #expect(last.contains { $0.isToday && $0.state == .pending })
        #expect(last.last?.state == .future)
    }

    @Test func statesFromHistory() {
        let history = [
            DaySnapshot(day: key("2026-12-14"), status: .done),
            DaySnapshot(day: key("2026-12-15"), status: .skipped),
        ]
        let model = HeatmapModel(snapshots: history, startedOn: key("2026-12-10"), today: key("2026-12-16"), calendar: utc)
        let cells = Dictionary(model.weeks.flatMap { $0 }.map { ($0.day, $0.state) }, uniquingKeysWith: { a, _ in a })
        #expect(cells[key("2026-12-14")] == .done)
        #expect(cells[key("2026-12-15")] == .rest)
        #expect(cells[key("2026-12-12")] == .missed)
        #expect(cells[key("2026-12-09")] == .beforeStart)
    }
}

@Suite("HabitDetailStats")
struct HabitDetailStatsTests {
    @Test func linesAndFractions() {
        let history = (0..<10).map { DaySnapshot(day: key("2026-12-01").adding(days: $0, calendar: utc), status: .done) }
        let stats = HabitDetailStats(snapshots: history, cadence: .daily, startedOn: key("2026-12-01"), today: key("2026-12-11"), calendar: utc)
        #expect(stats.streakText == "10 days")
        #expect(stats.graduation.daysActive == 11)
        #expect(stats.flightLine == "Day 11 · 91 % of the last 30 days")
        #expect(stats.restDaysLeft == 2)
        #expect(abs(stats.tickFraction - 30.0 / 66.0) < 0.0001)
    }
}
