import Foundation
import Testing
@testable import HabitCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

private func done(_ today: DayKey, daysBack: [Int], status: EntryStatus = .done) -> [DaySnapshot] {
    daysBack.map { DaySnapshot(day: today.adding(days: -$0, calendar: utc), status: status) }
}

@Suite("HoldingRate")
struct HoldingRateTests {
    let today = key("2026-12-20")

    @Test func countsTheFourteenDaysBeforeToday() {
        let snapshots = done(today, daysBack: Array(1...14))
        #expect(HoldingRate.rate(snapshots: snapshots, today: today, calendar: utc) == 1)
        let half = done(today, daysBack: Array(stride(from: 1, through: 14, by: 2)))
        #expect(HoldingRate.rate(snapshots: half, today: today, calendar: utc) == 0.5)
    }

    @Test func todayIsNotJudged() {
        let onlyToday = done(today, daysBack: [0])
        #expect(HoldingRate.rate(snapshots: onlyToday, today: today, calendar: utc) == 0)
    }

    @Test func restDaysCountAsMet() {
        let snapshots = done(today, daysBack: Array(1...7)) + done(today, daysBack: Array(8...14), status: .skipped)
        #expect(HoldingRate.rate(snapshots: snapshots, today: today, calendar: utc) == 1)
    }

    @Test func onlyDaysSinceGraduationCount() {
        let since = today.adding(days: -4, calendar: utc)
        let snapshots = done(today, daysBack: [1, 2, 3, 4])
        #expect(HoldingRate.rate(snapshots: snapshots, today: today, since: since, calendar: utc) == 1)
        #expect(HoldingRate.rate(snapshots: [], today: today, since: today, calendar: utc) == nil)
    }

    @Test func trendHasOnePointPerDay() {
        let trend = HoldingRate.trend(snapshots: done(today, daysBack: Array(1...14)), today: today, calendar: utc)
        #expect(trend.count == 14)
        #expect(trend.last == 1)
        #expect(trend.first! < 1)   // the oldest point's 7-day span reaches before the done days
    }
}
