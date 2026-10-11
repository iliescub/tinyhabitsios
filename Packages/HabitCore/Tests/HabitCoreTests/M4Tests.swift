import Foundation
import SwiftData
import Testing
@testable import HabitCore

@Suite("Pro and export")
struct M4Tests {
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    @Test func freeTierAllowsOneHealthHabit() {
        #expect(ProPolicy.canAddAutoHabit(isPro: false, activeAutoCount: 0))
        #expect(!ProPolicy.canAddAutoHabit(isPro: false, activeAutoCount: 1))
        #expect(ProPolicy.canAddAutoHabit(isPro: true, activeAutoCount: 2))
        #expect(ProStatus.productIDs.all.count == 3)
    }

    @Test func eveningSummary() {
        let today = DayKey(rawValue: "2026-12-15")!
        let now = ISO8601DateFormatter().date(from: "2026-12-15T12:00:00Z")!
        let open = ReminderPlan.Input(habitID: UUID(), name: "Walk", reminderMinutes: nil, todayStatus: .pending, remainingText: "1,800 steps to go.")
        let done = ReminderPlan.Input(habitID: UUID(), name: "Read", reminderMinutes: nil, todayStatus: .done)
        let reminders = ReminderPlan.eveningSummaries(minutes: 21 * 60, habits: [open, done], today: today, now: now, calendar: utc)
        #expect(reminders.count == ReminderPlan.horizonDays)
        #expect(reminders.first?.body == "1 of 2 done. Walk: 1,800 steps to go.")
        #expect(reminders.dropFirst().allSatisfy { $0.body == "How did your three habits go today?" })

        let allDone = ReminderPlan.eveningSummaries(minutes: 21 * 60, habits: [done], today: today, now: now, calendar: utc)
        #expect(allDone.count == ReminderPlan.horizonDays - 1)
        #expect(ReminderPlan.eveningSummaries(minutes: nil, habits: [open], today: today, now: now, calendar: utc).isEmpty)
    }

    @Test func eveningSummarySetting() {
        let saved = FledgeSettings.eveningSummaryMinutes
        defer { FledgeSettings.eveningSummaryMinutes = saved }
        FledgeSettings.eveningSummaryMinutes = 1260
        #expect(FledgeSettings.eveningSummaryMinutes == 1260)
        FledgeSettings.eveningSummaryMinutes = nil
        #expect(FledgeSettings.eveningSummaryMinutes == nil)
    }

    @Test func csvExport() throws {
        let context = ModelContext(try SharedStore.makeContainer(inMemory: true))
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk, outside", source: .steps, target: 6_000, unit: "steps"))
        try context.record(value: 6_200, habitID: walk.id, on: DayKey(rawValue: "2026-12-15")!, by: .auto)
        try context.record(value: 2_500.5, habitID: walk.id, on: DayKey(rawValue: "2026-12-14")!, by: .auto)
        let csv = CSVExporter.csv(CSVExporter.rows(from: try context.fetch(FetchDescriptor<Habit>())))
        #expect(csv == """
        date,habit,state,status,value,unit,completed_by
        2026-12-14,"Walk, outside",active,pending,2500.5,steps,
        2026-12-15,"Walk, outside",active,done,6200,steps,auto

        """)
    }
}
