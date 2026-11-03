import Foundation
import SwiftData
import Testing
@testable import HabitCore

// Edge cases and error paths that the feature suites don't reach: invalid raw values, missing records,
// legacy SchemaV1 accessors, settings round trips and boundary inputs.

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

@Suite("Model accessors")
struct ModelAccessorTests {
    @Test func schemaV1AccessorsRoundTrip() throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let habit = SchemaV1.Habit(name: "Walk", symbol: "figure.walk", source: .steps, target: 6_000, unit: "steps", perWeek: 9, slot: 0)
        context.insert(habit)
        #expect(habit.perWeek == 7)
        #expect(habit.state == .active)
        habit.state = .graduated
        #expect(habit.stateRaw == "graduated")
        habit.stateRaw = "bogus"
        #expect(habit.state == .active)
        #expect(habit.source == .steps)
        habit.source = .manual
        #expect(habit.sourceRaw == "manual")
        #expect(habit.cadence == Cadence(perWeek: 7))

        let log = SchemaV1.DayLog(dayKey: key("2026-10-20"), habit: habit)
        context.insert(log)
        #expect(log.status == .pending)
        log.status = .done
        #expect(log.statusRaw == "done")
        log.statusRaw = "bogus"
        #expect(log.status == .pending)
        #expect(log.completedBy == nil)
        log.completedBy = .widget
        #expect(log.completedByRaw == "widget")
        #expect(log.snapshot == DaySnapshot(day: key("2026-10-20"), status: .pending))
        log.dayKey = "not a day"
        #expect(log.snapshot == nil)
    }

    @Test func schemaV2InvalidRawValuesFallBack() {
        let habit = Habit(name: "Walk", symbol: "figure.walk")
        habit.stateRaw = "bogus"
        #expect(habit.state == .active)
        let log = DayLog(dayKey: key("2027-01-01"), habit: habit)
        log.statusRaw = "bogus"
        #expect(log.status == .pending)
        let resolution = Resolution(text: "Move more", year: 2027, startDay: key("2027-01-01"))
        #expect(resolution.startDay == key("2027-01-01"))
        resolution.stateRaw = "bogus"
        #expect(resolution.state == .active)
        resolution.startDayKey = ""
        #expect(resolution.startDay == nil)
    }

    @Test func dayKeyEdges() {
        #expect(key("2027-01-05").description == "2027-01-05")
        #expect(DayKey(rawValue: "2027-13-01") == nil)
        #expect(DayKey(rawValue: "2027-01") == nil)
        #expect(DayKey(rawValue: "x-y-z") == nil)
    }

    @Test func packTemplateCadenceAndMissingPack() throws {
        let daily = Pack.Template(name: "Read", symbol: "book.fill", source: .manual, target: 1, unit: "times")
        #expect(daily.cadence == Cadence(perWeek: 7))
        let weekly = Pack.Template(name: "Lift", symbol: "dumbbell.fill", source: .workout, target: 1, unit: "workout", perWeek: 3)
        #expect(weekly.cadence == Cadence(perWeek: 3))
        #expect(throws: PackLibrary.LoadError.self) { try PackLibrary.load("no-such-pack") }
        #expect(try ResolutionLibrary.template(id: "no-such-resolution") == nil)
    }
}

@Suite("Settings round trips", .serialized)
struct SettingsTests {
    @Test func proStatusAndSlipNudges() {
        let wasPro = ProStatus.isPro
        let nudged = FledgeSettings.slipNudgedHabitIDs
        defer {
            ProStatus.isPro = wasPro
            FledgeSettings.slipNudgedHabitIDs = nudged
        }
        ProStatus.isPro = true
        #expect(ProStatus.isPro)
        ProStatus.isPro = false
        #expect(!ProStatus.isPro)
        FledgeSettings.slipNudgedHabitIDs = ["b", "a"]
        #expect(FledgeSettings.slipNudgedHabitIDs == ["a", "b"])
    }
}

@Suite("Write API error paths")
@MainActor
struct WriteAPIErrorTests {
    @Test func missingHabitsThrowOrDoNothing() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let ghost = UUID()
        let day = key("2027-01-01")
        #expect(throws: HabitStoreError.habitNotFound) { try context.pause(habitID: ghost) }
        #expect(throws: HabitStoreError.habitNotFound) { try context.resume(habitID: ghost) }
        #expect(throws: HabitStoreError.habitNotFound) { try context.graduate(habitID: ghost) }
        #expect(throws: HabitStoreError.habitNotFound) { try context.skip(habitID: ghost, on: day) }
        #expect(throws: HabitStoreError.habitNotFound) { try context.addAmount(1, habitID: ghost, on: day) }
        #expect(throws: HabitStoreError.habitNotFound) { try context.updateHabit(habitID: ghost, with: HabitDraft(name: "x")) }
        #expect(throws: HabitStoreError.invalidDraft(.emptyName)) { try context.updateHabit(habitID: ghost, with: HabitDraft(name: " ")) }
        try context.deleteHabit(habitID: ghost)
        try context.setDone(true, habitID: ghost, on: day, by: .manual)
        try context.record(value: 5, habitID: ghost, on: day, by: .auto)
        #expect(try context.log(for: ghost, on: day) == nil)
    }

    @Test func deleteResumeActiveAndAmountAfterRest() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let day = key("2027-01-02")
        let read = try context.addHabit(draft: HabitDraft(name: "Read", symbol: "book.fill", perWeek: 3))
        try context.resume(habitID: read.id)          // already active: nothing happens
        #expect(read.state == .active)
        try context.skip(habitID: read.id, on: day)
        try context.addAmount(1, habitID: read.id, on: day)
        #expect(try context.log(for: read.id, on: day)?.status == .done)
        try context.deleteHabit(habitID: read.id)
        #expect(try context.habit(id: read.id) == nil)
    }

    @Test func writerSkipsOffTheMainActor() async throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let id = try container.mainContext.addHabit(draft: HabitDraft(name: "Read", symbol: "book.fill", perWeek: 3)).id
        let writer = HabitWriter(modelContainer: container)
        try await writer.skip(habitID: id, on: key("2027-01-02"))
        #expect(try container.mainContext.log(for: id, on: key("2027-01-02"))?.status == .skipped)
    }

    @Test func resolutionUpdatesListsAndMissingOnes() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let first = try context.startResolution(ResolutionDraft(text: "Move more"), startDay: key("2026-03-01"))
        try context.archiveResolution(id: first.id)
        let second = try context.startResolution(ResolutionDraft(text: "Read more"), startDay: key("2027-01-01"))
        #expect(try context.allResolutions().map(\.text) == ["Read more", "Move more"])

        try context.updateResolution(id: second.id, with: ResolutionDraft(text: " Read every night ", why: "Calm", letter: "Hi"))
        #expect(second.text == "Read every night")
        #expect(second.why == "Calm" && second.letter == "Hi")
        #expect(throws: HabitStoreError.invalidResolution(.emptyText)) {
            try context.updateResolution(id: second.id, with: ResolutionDraft(text: ""))
        }
        let ghost = UUID()
        #expect(throws: HabitStoreError.resolutionNotFound) { try context.updateResolution(id: ghost, with: ResolutionDraft(text: "x")) }
        #expect(throws: HabitStoreError.resolutionNotFound) { try context.archiveResolution(id: ghost) }
        #expect(throws: HabitStoreError.resolutionNotFound) { try context.scheduleFreshStart(resolutionID: ghost, on: key("2027-01-04")) }
    }

    @Test func resolutionDraftLimits() {
        #expect(ResolutionDraft(text: String(repeating: "a", count: 41)).problem == .textTooLong)
        #expect(ResolutionDraft(text: "ok", why: String(repeating: "a", count: 281)).problem == .whyTooLong)
        #expect(ResolutionDraft(text: "ok", letter: String(repeating: "a", count: 2_001)).problem == .letterTooLong)
        #expect(ResolutionDraft(text: "ok").problem == nil)
    }

    @Test func archivedResolutionsAreNeverKept() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let resolution = try context.startResolution(ResolutionDraft(text: "Move more"), startDay: key("2027-01-01"))
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", symbol: "figure.walk"))
        try context.archiveResolution(id: resolution.id)
        try context.graduate(habitID: walk.id)
        #expect(resolution.state == .archived)
    }

    @Test func aKeptResolutionStaysKeptWhileAnotherIsActive() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let first = try context.startResolution(ResolutionDraft(text: "Move more"), startDay: key("2027-01-01"))
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", symbol: "figure.walk"))
        try context.graduate(habitID: walk.id)
        #expect(first.state == .kept)
        _ = try context.startResolution(ResolutionDraft(text: "Sleep better"), startDay: key("2027-03-01"))
        try context.resume(habitID: walk.id)
        #expect(first.state == .kept)   // reopening would make two active resolutions
    }
}

@Suite("Engine edge cases")
struct EngineEdgeTests {
    @Test func weeklyStreakResetsAfterAShortWeek() {
        // Mon 4 Jan – Sun 10 Jan 2027: 3 done; 11–17 Jan: 1 done; 18–24 Jan: 3 done; today 27 Jan.
        var snapshots: [DaySnapshot] = []
        for day in ["2027-01-04", "2027-01-05", "2027-01-06", "2027-01-12", "2027-01-18", "2027-01-19", "2027-01-20"] {
            snapshots.append(DaySnapshot(day: key(day), status: .done))
        }
        let streak = StreakCalculator.streak(snapshots: snapshots, cadence: Cadence(perWeek: 3), today: key("2027-01-27"), startedOn: key("2027-01-04"), calendar: utc)
        #expect(streak.unit == .weeks)
        #expect(streak.best == 1)
        #expect(streak.current == 1)
    }

    @Test func flightForecastGivesUpBeyondTheHorizon() {
        let day = FlightForecast.flyDate(
            snapshots: [], cadence: Cadence(perWeek: 7), startedOn: key("2027-01-01"), today: key("2027-01-01"), horizon: 3, calendar: utc
        )
        #expect(day == nil)
    }

    @Test func freshStartEdges() {
        // Every day a rest day: nothing planned, so no lapse.
        let rest = (0..<7).map { DaySnapshot(day: key("2027-01-13").adding(days: $0, calendar: utc), status: .skipped) }
        #expect(!FreshStart.hasLapsed(habits: [(7, rest)], startedOn: key("2027-01-01"), today: key("2027-01-20"), calendar: utc))
        #expect(!FreshStart.hasLapsed(habits: [FreshStart.Habit](), startedOn: key("2027-01-01"), today: key("2027-01-20"), calendar: utc))
        #expect(FreshStart.smallerTarget(10, step: 0) == 10)
        // Duplicate logs for a day: the last one counts.
        let dupes = [DaySnapshot(day: key("2027-01-09"), status: .pending), DaySnapshot(day: key("2027-01-09"), status: .done)]
        #expect(MissCheck.missedOnlyYesterday(snapshots: dupes, perWeek: 7, startedOn: key("2027-01-01"), today: key("2027-01-11"), calendar: utc))
    }

    @Test func yearMapBeforeAnyHabitStarted() {
        // The resolution started on the 1st; its only habit on the 3rd.
        let habit = YearMap.Habit(startedOn: key("2027-01-03"), snapshots: [])
        let dots = YearMap.dots(from: key("2027-01-01"), through: key("2027-01-04"), startDay: key("2027-01-01"), habits: [habit], today: key("2027-01-04"), calendar: utc)
        #expect(dots == [.before, .before, .empty, .future])
        let none = YearMap.dots(from: key("2027-01-04"), through: key("2027-01-04"), startDay: key("2027-01-01"), habits: [YearMap.Habit](), today: key("2027-01-04"), calendar: utc)
        #expect(none == [.future])
    }

    @Test func healthAggregationEdges() {
        let day = DateInterval(start: Date(timeIntervalSince1970: 0), duration: 86_400)
        // No sleep at all, and an interval outside the range.
        #expect(HealthAggregation.mainSleepHours(asleep: [], window: day) == 0)
        let outside = DateInterval(start: Date(timeIntervalSince1970: 200_000), duration: 600)
        #expect(HealthAggregation.totalMinutes([outside], within: day) == 0)
    }

    @Test func eveningSummaryNamesAnOpenHabitWithoutAnAmount() {
        let id = UUID()
        let inputs = [ReminderPlan.Input(habitID: id, name: "Read", reminderMinutes: nil, todayStatus: .pending)]
        let now = key("2027-01-10").date(in: utc).addingTimeInterval(-6 * 3_600)
        let summaries = ReminderPlan.eveningSummaries(minutes: 20 * 60, habits: inputs, today: key("2027-01-10"), now: now, calendar: utc)
        #expect(summaries.first?.body == "0 of 1 done. Read is still open.")
        #expect(summaries.first?.title == "Yearling")
    }

    @Test func csvSkipsHabitsWithoutLogs() {
        let habit = Habit(name: "Walk", symbol: "figure.walk")
        habit.logs = nil
        #expect(CSVExporter.rows(from: [habit]).isEmpty)
    }
}


@Suite("Review fixes (2026-11-02)")
@MainActor
struct ReviewFixTests {
    @Test func aHabitAddedThisWeekCantHaveLapsed() {
        let today = key("2027-02-10")
        // The only active habit was added yesterday; the resolution is a month old.
        let fresh = FreshStart.Habit(perWeek: 7, startedOn: key("2027-02-09"), snapshots: [])
        #expect(!FreshStart.hasLapsed(habits: [fresh], startedOn: key("2027-01-10"), today: today, calendar: utc))
        // Backfilled Health days from before a habit started don't hide a real lapse of an older one.
        let old = FreshStart.Habit(perWeek: 7, startedOn: key("2027-01-10"), snapshots: [])
        let backfilled = FreshStart.Habit(perWeek: 7, startedOn: key("2027-02-08"),
                                          snapshots: (3...9).map { DaySnapshot(day: today.adding(days: -$0, calendar: utc), status: .done) })
        #expect(FreshStart.hasLapsed(habits: [old, backfilled], startedOn: key("2027-01-10"), today: today, calendar: utc))
    }

    @Test func weeklyHabitsDontMakeOffDaysPartial() {
        let daily = YearMap.Habit(startedOn: key("2027-01-04"), snapshots: (0..<7).map { DaySnapshot(day: key("2027-01-04").adding(days: $0, calendar: utc), status: .done) })
        let lift = YearMap.Habit(startedOn: key("2027-01-04"), perWeek: 3, snapshots: [DaySnapshot(day: key("2027-01-04"), status: .done)])
        let dots = YearMap.dots(from: key("2027-01-04"), through: key("2027-01-10"), startDay: key("2027-01-04"), habits: [daily, lift], today: key("2027-01-11"), calendar: utc)
        #expect(dots.allSatisfy { $0 == .full })
        // Only weekly habits, none done that day: empty, never "before".
        let alone = YearMap.dots(from: key("2027-01-05"), through: key("2027-01-05"), startDay: key("2027-01-04"), habits: [lift], today: key("2027-01-11"), calendar: utc)
        #expect(alone == [.empty])
    }

    @Test func deletingTheLastUnflownHabitKeepsTheResolution() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let resolution = try context.startResolution(ResolutionDraft(text: "Move more"), startDay: key("2027-01-01"))
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", symbol: "figure.walk"))
        let read = try context.addHabit(draft: HabitDraft(name: "Read", symbol: "book.fill"))
        try context.graduate(habitID: walk.id)
        #expect(resolution.state == .active)
        try context.deleteHabit(habitID: read.id)
        #expect(resolution.state == .kept)
    }

    @Test func pausedHabitsBlockKeeping() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let resolution = try context.startResolution(ResolutionDraft(text: "Move more"), startDay: key("2027-01-01"))
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", symbol: "figure.walk"))
        let read = try context.addHabit(draft: HabitDraft(name: "Read", symbol: "book.fill"))
        try context.pause(habitID: read.id)
        try context.graduate(habitID: walk.id)
        #expect(resolution.state == .active)
    }

    @Test func blankLettersAreStoredAsNone() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let resolution = try context.startResolution(ResolutionDraft(text: "Move more", why: "  ", letter: " \n "), startDay: key("2027-01-01"))
        #expect(resolution.letter.isEmpty && resolution.why.isEmpty)
        try context.updateResolution(id: resolution.id, with: ResolutionDraft(text: "Move more", why: " Energy ", letter: " Hi \n"))
        #expect(resolution.why == "Energy" && resolution.letter == "Hi")
    }

    @Test func shortKeywordsNoLongerMatchLongerWords() throws {
        let templates = try ResolutionLibrary.all()
        #expect(ResolutionLibrary.match("Try new restaurants", in: templates) == nil)
        #expect(ResolutionLibrary.match("Feel less stressed", in: templates)?.id == "calmer-mind")
    }

    @Test func dayKeysAreGregorianWhateverTheCalendar() {
        let fledge = Calendar.fledge
        #expect(fledge.identifier == .gregorian)
        #expect(fledge.timeZone == .current)
        let date = utc.date(from: DateComponents(year: 2027, month: 3, day: 5, hour: 12))!
        var hebrew = Calendar(identifier: .hebrew)
        hebrew.timeZone = TimeZone(identifier: "UTC")!
        #expect(hebrew.component(.year, from: date) != 2027)
        // DayKey's default calendar is Gregorian, so the key reads 2027 even for a Hebrew-calendar user.
        #expect(DayKey(date, calendar: .fledge, dayEndHour: 0).year == 2027)
    }
}

@Suite("Goal edits re-check today")
@MainActor
struct GoalEditTests {
    @Test func aLoweredGoalThatsMetIsDoneNow() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let day = key("2027-02-12")
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", symbol: "figure.walk", source: .steps, target: 6_000, unit: "steps"))
        try context.record(value: 4_210, habitID: walk.id, on: day, by: .auto)
        #expect(try context.log(for: walk.id, on: day)?.status == .pending)
        var draft = HabitDraft(habit: walk)
        draft.target = 3_000
        try context.updateHabit(habitID: walk.id, with: draft, reevaluating: day)
        let log = try #require(try context.log(for: walk.id, on: day))
        #expect(log.status == .done)
        #expect(log.completedBy == .auto)
        // Without a day nothing is re-checked, and a day without a value is left alone.
        draft.target = 5_000
        try context.updateHabit(habitID: walk.id, with: draft, reevaluating: key("2027-02-13"))
        #expect(try context.log(for: walk.id, on: key("2027-02-13"))?.value == 0)
    }
}
