import Foundation
import SwiftData
import Testing
@testable import HabitCore

@Suite("Habit drafts")
struct HabitDraftTests {
    @Test func validation() {
        #expect(HabitDraft(name: "  ").problem == .emptyName)
        #expect(HabitDraft(name: String(repeating: "a", count: 31)).problem == .nameTooLong)
        #expect(HabitDraft(name: "Read", target: 0).problem == .targetNotPositive)
        #expect(HabitDraft(name: "Read", reminderMinutes: 24 * 60).problem == .invalidReminder)
        #expect(HabitDraft(name: " Read ", reminderMinutes: 21 * 60).problem == nil)
    }

    @Test func addAndEditKeepHistory() throws {
        let context = ModelContext(try SharedStore.makeContainer(inMemory: true))
        let habit = try context.addHabit(draft: HabitDraft(name: " Read ", symbol: "book.fill", reminderMinutes: 1260))
        #expect(habit.name == "Read")
        #expect(habit.reminderMinutes == 1260)

        let day = DayKey(rawValue: "2026-12-15")!
        try context.setDone(true, habitID: habit.id, on: day, by: .manual)

        var draft = HabitDraft(habit: habit)
        draft.name = "Read fiction"
        draft.target = 20
        draft.unit = "pages"
        draft.perWeek = 5
        try context.updateHabit(habitID: habit.id, with: draft)
        #expect(habit.name == "Read fiction")
        #expect(habit.cadence == Cadence(perWeek: 5))
        #expect(habit.logs?.count == 1)

        draft.name = ""
        #expect(throws: HabitStoreError.invalidDraft(.emptyName)) { try context.updateHabit(habitID: habit.id, with: draft) }
    }
}

@Suite("Rest days and amounts")
struct RestDayTests {
    private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

    @Test func policyCountsSkipsInTheSameMonth() {
        let history = [
            DaySnapshot(day: key("2026-11-30"), status: .skipped),
            DaySnapshot(day: key("2026-12-02"), status: .skipped),
        ]
        #expect(RestDayPolicy.remaining(snapshots: history, cadence: .daily, on: key("2026-12-10")) == 1)
        #expect(RestDayPolicy.remaining(snapshots: history, cadence: Cadence(perWeek: 3), on: key("2026-12-10")) == nil)
    }

    @Test func dailyHabitGetsTwoRestDaysPerMonth() throws {
        let context = ModelContext(try SharedStore.makeContainer(inMemory: true))
        let habit = try context.addHabit(draft: HabitDraft(name: "Walk", source: .steps, target: 6_000, unit: "steps"))
        try context.skip(habitID: habit.id, on: key("2026-12-01"))
        try context.skip(habitID: habit.id, on: key("2026-12-05"))
        // Re-skipping a day that is already a rest day is fine.
        try context.skip(habitID: habit.id, on: key("2026-12-05"))
        #expect(throws: HabitStoreError.noRestDaysLeft) { try context.skip(habitID: habit.id, on: key("2026-12-09")) }
        // New month, new passes.
        try context.skip(habitID: habit.id, on: key("2027-01-02"))
    }

    @Test func amountsAccumulateAndComplete() throws {
        let context = ModelContext(try SharedStore.makeContainer(inMemory: true))
        let habit = try context.addHabit(draft: HabitDraft(name: "Stretch", target: 10, unit: "min"))
        let day = key("2026-12-15")
        try context.addAmount(5, habitID: habit.id, on: day)
        #expect(try context.log(for: habit.id, on: day)?.status == .pending)
        try context.addAmount(5, habitID: habit.id, on: day)
        let log = try context.log(for: habit.id, on: day)
        #expect(log?.value == 10)
        #expect(log?.status == .done)
        #expect(log?.completedBy == .manual)
    }

    @Test func dayKeyTodayUsesSharedDayEndHour() {
        let date = ISO8601DateFormatter().date(from: "2026-12-16T01:30:00Z")!
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let saved = FledgeSettings.dayEndHour
        defer { FledgeSettings.dayEndHour = saved }
        FledgeSettings.dayEndHour = 0
        #expect(DayKey.today(now: date, calendar: utc).rawValue == "2026-12-16")
        FledgeSettings.dayEndHour = 3
        #expect(DayKey.today(now: date, calendar: utc).rawValue == "2026-12-15")
        FledgeSettings.dayEndHour = 9
        #expect(FledgeSettings.dayEndHour == 5)
    }
}
