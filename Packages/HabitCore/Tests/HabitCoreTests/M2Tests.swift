import Foundation
import SwiftData
import Testing
@testable import HabitCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }
private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }
private func span(_ start: String, _ end: String) -> DateInterval { DateInterval(start: date(start), end: date(end)) }

@Suite("HealthAggregation")
struct HealthAggregationTests {
    @Test func dayIntervalUsesDayEndHour() {
        let interval = HealthAggregation.dayInterval(key("2026-12-15"), dayEndHour: 3, calendar: utc)
        #expect(interval.start == date("2026-12-15T03:00:00Z"))
        #expect(interval.end == date("2026-12-16T03:00:00Z"))
    }

    @Test func mainSleepMergesShortWakeupsAndIgnoresNaps() {
        let window = HealthAggregation.sleepWindow(for: key("2026-12-15"), calendar: utc)
        #expect(window.start == date("2026-12-14T18:00:00Z"))
        let asleep = [
            span("2026-12-14T23:00:00Z", "2026-12-15T02:00:00Z"),
            span("2026-12-15T02:10:00Z", "2026-12-15T06:30:00Z"), // 10-min wake-up → same night
            span("2026-12-15T13:00:00Z", "2026-12-15T13:40:00Z"), // nap → separate, shorter
        ]
        let hours = HealthAggregation.mainSleepHours(asleep: asleep, window: window)
        #expect(abs(hours - (3 + 4 + 20.0 / 60)) < 0.001)
    }

    @Test func sleepOutsideWindowDoesNotCount() {
        let window = HealthAggregation.sleepWindow(for: key("2026-12-15"), calendar: utc)
        let previousNight = [span("2026-12-13T23:00:00Z", "2026-12-14T07:00:00Z")]
        #expect(HealthAggregation.mainSleepHours(asleep: previousNight, window: window) == 0)
    }

    @Test func minutesAreClippedToTheDay() {
        let day = HealthAggregation.dayInterval(key("2026-12-15"), dayEndHour: 0, calendar: utc)
        let sessions = [
            span("2026-12-14T23:50:00Z", "2026-12-15T00:10:00Z"), // 10 min inside
            span("2026-12-15T08:00:00Z", "2026-12-15T08:05:00Z"),
        ]
        #expect(abs(HealthAggregation.totalMinutes(sessions, within: day) - 15) < 0.001)
    }

    @Test func noDataHint() {
        #expect(NoDataHeuristic.shouldHint(todayValue: 0, previousValues: [0, 0], daysActive: 5, hour: 19))
        #expect(!NoDataHeuristic.shouldHint(todayValue: 0, previousValues: [0, 0], daysActive: 5, hour: 12))
        #expect(!NoDataHeuristic.shouldHint(todayValue: 0, previousValues: [0, 120], daysActive: 5, hour: 19))
        #expect(!NoDataHeuristic.shouldHint(todayValue: 0, previousValues: [0, 0], daysActive: 2, hour: 19))
    }
}

@Suite("ReminderPlan")
struct ReminderPlanTests {
    private let id = UUID()

    @Test func pendingHabitGetsTodayAndNextDays() {
        let input = ReminderPlan.Input(habitID: id, name: "Read", reminderMinutes: 20 * 60, todayStatus: .pending, remainingText: "10 min to go.")
        let reminders = ReminderPlan.reminders(for: [input], today: key("2026-12-15"), now: date("2026-12-15T12:00:00Z"), calendar: utc)
        #expect(reminders.count == ReminderPlan.horizonDays)
        #expect(reminders.first?.fireDate == date("2026-12-15T20:00:00Z"))
        #expect(reminders.first?.body == "Still in the nest today. 10 min to go.")
        #expect(reminders.first?.identifier.hasPrefix(ReminderPlan.identifierPrefix) == true)
    }

    @Test func doneOrPastSkipsToday() {
        let done = ReminderPlan.Input(habitID: id, name: "Read", reminderMinutes: 20 * 60, todayStatus: .done)
        let late = ReminderPlan.Input(habitID: UUID(), name: "Walk", reminderMinutes: 9 * 60, todayStatus: .pending)
        let reminders = ReminderPlan.reminders(for: [done, late], today: key("2026-12-15"), now: date("2026-12-15T12:00:00Z"), calendar: utc)
        #expect(!reminders.contains { $0.fireDate < date("2026-12-16T00:00:00Z") })
        #expect(reminders.count == 2 * (ReminderPlan.horizonDays - 1))
    }

    @Test func noReminderTimeNoReminders() {
        let input = ReminderPlan.Input(habitID: id, name: "Read", reminderMinutes: nil, todayStatus: .pending)
        #expect(ReminderPlan.reminders(for: [input], today: key("2026-12-15"), now: .distantPast, calendar: utc).isEmpty)
    }
}

@Suite("Health sync write path")
struct HealthSyncWriteTests {
    @Test func trackedAutoHabitsIncludeGraduatesButNotPaused() throws {
        let context = ModelContext(try SharedStore.makeContainer(inMemory: true))
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", source: .steps, target: 6_000, unit: "steps"))
        let sleep = try context.addHabit(draft: HabitDraft(name: "Sleep", source: .sleep, target: 7, unit: "h"))
        try context.addHabit(draft: HabitDraft(name: "Read"))
        try context.graduate(habitID: walk.id)
        try context.pause(habitID: sleep.id)
        let refs = try context.trackedAutoHabits()
        #expect(refs.map(\.id) == [walk.id])
    }

    @Test func autoValueCompletesAndRepeatedValueIsNoOp() throws {
        let context = ModelContext(try SharedStore.makeContainer(inMemory: true))
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", source: .steps, target: 6_000, unit: "steps"))
        let day = key("2026-12-15")
        try context.record(value: 6_200, habitID: walk.id, on: day, by: .auto)
        let log = try #require(try context.log(for: walk.id, on: day))
        let stamp = log.updatedAt
        try context.record(value: 6_200, habitID: walk.id, on: day, by: .auto)
        #expect(log.status == .done)
        #expect(log.completedBy == .auto)
        #expect(log.updatedAt == stamp)
    }
}
