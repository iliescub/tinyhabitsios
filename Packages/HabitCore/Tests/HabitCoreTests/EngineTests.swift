import Foundation
import Testing
@testable import HabitCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2 // Monday
    return calendar
}()

private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

private func days(from start: String, count: Int, status: EntryStatus) -> [DaySnapshot] {
    (0..<count).map { DaySnapshot(day: key(start).adding(days: $0, calendar: utc), status: status) }
}

@Suite("DayKey")
struct DayKeyTests {
    @Test func lateNightCountsForPreviousDay() {
        let date = ISO8601DateFormatter().date(from: "2026-12-16T01:30:00Z")!
        #expect(DayKey(date, calendar: utc, dayEndHour: 3).rawValue == "2026-12-15")
        #expect(DayKey(date, calendar: utc, dayEndHour: 0).rawValue == "2026-12-16")
    }

    @Test func arithmeticCrossesYearBoundary() {
        #expect(key("2026-12-31").adding(days: 1, calendar: utc) == key("2027-01-01"))
        #expect(key("2026-12-15").days(to: key("2027-01-15"), calendar: utc) == 31)
    }

    @Test func rejectsInvalidStrings() {
        #expect(DayKey(rawValue: "2026-13-01") == nil)
        #expect(DayKey(rawValue: "hello") == nil)
    }
}

@Suite("DayEvaluator")
struct DayEvaluatorTests {
    @Test func autoHabitCompletesAtTarget() {
        let progress = DayEvaluator.evaluate(value: 6_000, target: 6_000, stored: .pending, completedBy: nil)
        #expect(progress.status == .done)
        #expect(progress.fraction == 1)
    }

    @Test func partialProgressFillsRing() {
        let progress = DayEvaluator.evaluate(value: 1_500, target: 6_000, stored: .pending, completedBy: nil)
        #expect(progress.status == .pending)
        #expect(progress.fraction == 0.25)
    }

    @Test func manualDoneIsSticky() {
        let progress = DayEvaluator.evaluate(value: 0, target: 6_000, stored: .done, completedBy: .manual)
        #expect(progress.status == .done)
    }

    @Test func skippedStaysSkipped() {
        let progress = DayEvaluator.evaluate(value: 9_000, target: 6_000, stored: .skipped, completedBy: nil)
        #expect(progress.status == .skipped)
    }

    @Test func incrementIsAQuarterOfTarget() {
        #expect(DayEvaluator.increment(for: 20) == 5)
        #expect(DayEvaluator.increment(for: 1) == 1)
    }
}

@Suite("StreakCalculator")
struct StreakTests {
    @Test func dailyStreakIgnoresPendingToday() {
        let history = days(from: "2026-12-01", count: 5, status: .done)
        let streak = StreakCalculator.streak(snapshots: history, cadence: .daily, today: key("2026-12-06"), startedOn: key("2026-12-01"), calendar: utc)
        #expect(streak.current == 5)
        #expect(streak.best == 5)
    }

    @Test func missedDayBreaksDailyStreakButSkipDoesNot() {
        var history = days(from: "2026-12-01", count: 3, status: .done)
        history.append(DaySnapshot(day: key("2026-12-04"), status: .skipped))
        history += days(from: "2026-12-05", count: 2, status: .done)
        // 2026-12-07 missing (missed), 2026-12-08 done
        history.append(DaySnapshot(day: key("2026-12-08"), status: .done))

        let streak = StreakCalculator.streak(snapshots: history, cadence: .daily, today: key("2026-12-08"), startedOn: key("2026-12-01"), calendar: utc)
        #expect(streak.best == 5)
        #expect(streak.current == 1)
    }

    @Test func weeklyCadenceCountsWeeks() {
        // Three done days in each of two Mon–Sun weeks (2026-11-30 is a Monday).
        let history = ["2026-11-30", "2026-12-02", "2026-12-04", "2026-12-07", "2026-12-09", "2026-12-11"]
            .map { DaySnapshot(day: key($0), status: .done) }
        let streak = StreakCalculator.streak(snapshots: history, cadence: Cadence(perWeek: 3), today: key("2026-12-15"), startedOn: key("2026-11-30"), calendar: utc)
        #expect(streak.unit == .weeks)
        #expect(streak.current == 2) // current week (Dec 14–20) not yet met, but not broken
        #expect(streak.best == 2)
    }
}

@Suite("GraduationEvaluator")
struct GraduationTests {
    @Test func notReadyBeforeMinimumDays() {
        let history = days(from: "2026-12-01", count: 20, status: .done)
        let status = GraduationEvaluator.status(snapshots: history, cadence: .daily, startedOn: key("2026-12-01"), today: key("2026-12-20"), calendar: utc)
        #expect(status.daysActive == 20)
        #expect(!status.isReady)
        #expect(status.daysToSuggested == 46)
    }

    @Test func readyAfterThirtyStrongDays() {
        var history = days(from: "2026-12-01", count: 30, status: .done)
        history.removeLast(5) // 25 of 30 = 83%
        let status = GraduationEvaluator.status(snapshots: history, cadence: .daily, startedOn: key("2026-12-01"), today: key("2026-12-30"), calendar: utc)
        #expect(status.isReady)
    }

    @Test func notReadyBelowThreshold() {
        let history = days(from: "2026-12-01", count: 20, status: .done) // 20 of 30 = 67%
        let status = GraduationEvaluator.status(snapshots: history, cadence: .daily, startedOn: key("2026-12-01"), today: key("2026-12-30"), calendar: utc)
        #expect(!status.isReady)
    }

    @Test func skippedDaysDoNotCountAgainst() {
        var history = days(from: "2026-12-01", count: 24, status: .done)
        history += days(from: "2026-12-25", count: 6, status: .skipped) // 24 of 24 expected
        let status = GraduationEvaluator.status(snapshots: history, cadence: .daily, startedOn: key("2026-12-01"), today: key("2026-12-30"), calendar: utc)
        #expect(status.recentRate == 1)
        #expect(status.isReady)
    }
}

@Suite("Packs and slots")
struct PackTests {
    @Test func essentialsPackLoads() throws {
        let pack = try PackLibrary.essentials()
        #expect(pack.id == "essentials")
        #expect(pack.templates.count == 10)
        #expect(pack.templates.filter { $0.source.isAuto }.count == 8)
        #expect(pack.graduation == .standard)
    }

    @Test func slotPolicyFindsLowestFreeSlot() {
        #expect(SlotPolicy.nextFreeSlot(occupied: []) == 0)
        #expect(SlotPolicy.nextFreeSlot(occupied: [0, 2]) == 1)
        #expect(SlotPolicy.nextFreeSlot(occupied: [0, 1, 2]) == nil)
    }
}
