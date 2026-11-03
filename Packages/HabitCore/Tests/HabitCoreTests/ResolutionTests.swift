import Foundation
import SwiftData
import Testing
@testable import HabitCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

/// Snapshots for consecutive days starting at `from`: "d" done, "s" skipped, "-" pending.
private func days(_ pattern: String, from: String) -> [DaySnapshot] {
    pattern.enumerated().map { offset, char in
        let status: EntryStatus = char == "d" ? .done : char == "s" ? .skipped : .pending
        return DaySnapshot(day: key(from).adding(days: offset, calendar: utc), status: status)
    }
}

@Suite("ResolutionYear")
struct ResolutionYearTests {
    @Test func novemberAndDecemberStartsCountForNextYear() {
        #expect(ResolutionYear.year(startingOn: key("2026-12-20")) == 2027)
        #expect(ResolutionYear.year(startingOn: key("2026-11-01")) == 2027)
        #expect(ResolutionYear.year(startingOn: key("2026-10-31")) == 2026)
        #expect(ResolutionYear.year(startingOn: key("2027-03-02")) == 2027)
        #expect(ResolutionYear.daysUntilStart(of: 2027, from: key("2026-12-15"), calendar: utc) == 17)
        #expect(ResolutionYear.daysUntilStart(of: 2027, from: key("2027-02-01"), calendar: utc) == 0)
    }

    @Test func dayNumberIsClampedToTheYear() {
        #expect(ResolutionYear.dayNumber(key("2027-01-01"), in: 2027, calendar: utc) == 1)
        #expect(ResolutionYear.dayNumber(key("2027-02-01"), in: 2027, calendar: utc) == 32)
        #expect(ResolutionYear.dayNumber(key("2026-12-28"), in: 2027, calendar: utc) == 0)
        #expect(ResolutionYear.dayNumber(key("2028-01-04"), in: 2027, calendar: utc) == 365)
        #expect(ResolutionYear.dayCount(of: 2028, calendar: utc) == 366)
    }

    @Test func letterOpensOnDecemberFirstOrWhenKept() {
        #expect(!ResolutionYear.isLetterOpen(today: key("2027-11-30"), year: 2027, kept: false))
        #expect(ResolutionYear.isLetterOpen(today: key("2027-12-01"), year: 2027, kept: false))
        #expect(ResolutionYear.isLetterOpen(today: key("2027-04-10"), year: 2027, kept: true))
    }

    @Test func wobbleDayIsTheSecondFridayOfJanuary() {
        #expect(ResolutionYear.wobbleDay(in: 2027, calendar: utc) == key("2027-01-08"))
        #expect(ResolutionYear.wobbleDay(in: 2028, calendar: utc) == key("2028-01-14"))
    }
}

@Suite("FreshStart")
struct FreshStartTests {
    @Test func landmarksPreferNewYearThenMonthThenWeek() {
        #expect(FreshStart.landmark(of: key("2027-01-01"), calendar: utc) == .newYear)
        #expect(FreshStart.landmark(of: key("2027-02-01"), calendar: utc) == .newMonth) // also a Monday
        #expect(FreshStart.landmark(of: key("2027-01-11"), calendar: utc) == .newWeek)
        #expect(FreshStart.landmark(of: key("2027-01-13"), calendar: utc) == nil)
    }

    @Test func nextLandmarkSkipsToday() {
        #expect(FreshStart.nextLandmark(after: key("2027-01-06"), calendar: utc) == .init(day: key("2027-01-11"), landmark: .newWeek))
        #expect(FreshStart.nextLandmark(after: key("2027-01-29"), calendar: utc) == .init(day: key("2027-02-01"), landmark: .newMonth))
        #expect(FreshStart.nextLandmark(after: key("2026-12-30"), calendar: utc) == .init(day: key("2027-01-01"), landmark: .newYear))
        #expect(FreshStart.nextLandmark(after: key("2027-01-11"), calendar: utc).day == key("2027-01-18"))
    }

    @Test func lapseNeedsAFullWeekAndAtMostTwoOfSeven() {
        let today = key("2027-01-20")
        let weak = days("d-d----", from: "2027-01-13")
        let fine = days("ddd-d--", from: "2027-01-13")
        #expect(FreshStart.hasLapsed(habits: [(7, weak)], startedOn: key("2027-01-01"), today: today, calendar: utc))
        #expect(!FreshStart.hasLapsed(habits: [(7, fine)], startedOn: key("2027-01-01"), today: today, calendar: utc))
        // Too new to lapse.
        #expect(!FreshStart.hasLapsed(habits: [(7, weak)], startedOn: key("2027-01-15"), today: today, calendar: utc))
        // Across habits: one strong habit carries a weak one.
        #expect(!FreshStart.hasLapsed(habits: [(7, weak), (7, days("ddddddd", from: "2027-01-13"))], startedOn: key("2027-01-01"), today: today, calendar: utc))
    }

    @Test func restDaysAndWeeklyCadenceDontCountAgainstIt() {
        let today = key("2027-01-20")
        // Three times a week, met twice: 2 of 3 planned.
        #expect(!FreshStart.hasLapsed(habits: [(3, days("d---d--", from: "2027-01-13"))], startedOn: key("2027-01-01"), today: today, calendar: utc))
        // Daily, two done and four rest days: 2 of 3 planned.
        #expect(!FreshStart.hasLapsed(habits: [(7, days("dssss-d", from: "2027-01-13"))], startedOn: key("2027-01-01"), today: today, calendar: utc))
    }

    @Test func offerIsShownOncePerLapse() {
        let today = key("2027-01-20")
        #expect(FreshStart.shouldOffer(lapsed: true, lastFreshStart: nil, today: today, calendar: utc))
        #expect(!FreshStart.shouldOffer(lapsed: true, lastFreshStart: key("2027-01-18"), today: today, calendar: utc))
        #expect(FreshStart.shouldOffer(lapsed: true, lastFreshStart: key("2027-01-11"), today: today, calendar: utc))
        #expect(!FreshStart.shouldOffer(lapsed: false, lastFreshStart: nil, today: today, calendar: utc))
    }

    @Test func smallerTargetHalvesOnTheGrid() {
        #expect(FreshStart.smallerTarget(6_000, step: 500) == 3_000)
        #expect(FreshStart.smallerTarget(7, step: 0.5) == 3.5)
        #expect(FreshStart.smallerTarget(1, step: 1) == 1)
    }
}

@Suite("Resolution framing and templates")
struct ResolutionFramingTests {
    @Test func spotsAvoidanceWording() {
        #expect(ResolutionFraming.isAvoidance("Stop scrolling at night"))
        #expect(ResolutionFraming.isAvoidance("I will quit smoking"))
        #expect(ResolutionFraming.isAvoidance("Don\u{2019}t drink soda"))
        #expect(ResolutionFraming.isAvoidance("less  phone"))
        #expect(!ResolutionFraming.isAvoidance("Read more"))
        #expect(!ResolutionFraming.isAvoidance("Sleep better"))
        #expect(!ResolutionFraming.isAvoidance("Notice the good things")) // "not" only as a whole word
    }

    @Test func libraryLoadsAndFollowsTheRules() throws {
        let templates = try ResolutionLibrary.all()
        #expect(templates.count >= 6)
        #expect(Set(templates.map(\.id)).count == templates.count)
        let colors: Set = ["dawn", "sky", "meadow", "gold", "lilac", "teal", "rose", "slate"]
        for template in templates {
            #expect(!template.habits.isEmpty && template.habits.count <= SlotPolicy.maxActive, "\(template.id)")
            #expect(colors.contains(template.accent), "\(template.id)")
            #expect(template.habits.allSatisfy { ($0.cue ?? "").count <= HabitDraft.maxCueLength && $0.name.count <= HabitDraft.maxNameLength })
            #expect(!ResolutionFraming.isAvoidance(template.title), "\(template.id) must be an approach goal")
        }
    }

    @Test func matchesTypedResolutions() throws {
        let templates = try ResolutionLibrary.all()
        #expect(ResolutionLibrary.match("Stop doomscrolling at night", in: templates)?.id == "evenings-off-phone")
        #expect(ResolutionLibrary.match("go to bed earlier, less tired", in: templates)?.id == "sleep-better")
        #expect(ResolutionLibrary.match("Quit soda", in: templates)?.id == "drink-water")
        #expect(ResolutionLibrary.match("Be less stressed", in: templates)?.id == "calmer-mind")
        #expect(ResolutionLibrary.match("Learn the cello", in: templates)?.id == "read-more" || ResolutionLibrary.match("Learn the cello", in: templates) == nil)
        #expect(ResolutionLibrary.match("zzz qqq", in: templates) == nil)
    }

    @Test func templateCueReachesTheDraft() throws {
        let template = try #require(try ResolutionLibrary.template(id: "sleep-better"))
        let id = UUID()
        let draft = HabitDraft(template: template.habits[0], colorKey: "lilac", packID: template.id, resolutionID: id)
        #expect(draft.cue == "When my alarm for bed goes off")
        #expect(draft.resolutionID == id)
        var long = draft
        long.cue = String(repeating: "a", count: HabitDraft.maxCueLength + 1)
        #expect(long.problem == .cueTooLong)
    }
}

@Suite("KeptCheck and YearMap")
struct YearMapTests {
    @Test func keptNeedsEveryHabitFlown() {
        #expect(KeptCheck.isKept(habitStates: [.graduated, .graduated]))
        #expect(!KeptCheck.isKept(habitStates: [.graduated, .active]))
        #expect(!KeptCheck.isKept(habitStates: [.graduated, .paused]))
        #expect(!KeptCheck.isKept(habitStates: []))
    }

    @Test func dotsShowBeforeFullPartialEmptyFuture() {
        let walk = days("ddd-", from: "2027-01-03")
        let read = days("ds--", from: "2027-01-04")
        let dots = YearMap.dots(
            year: 2027, startDay: key("2027-01-03"),
            habits: [(key("2027-01-03"), walk), (key("2027-01-04"), read)],
            today: key("2027-01-07"), calendar: utc
        )
        #expect(dots.count == 365)
        #expect(Array(dots[0..<7]) == [.before, .before, .full, .full, .full, .empty, .future])
        #expect(dots.last == .future)

        let partial = YearMap.dots(
            year: 2027, startDay: key("2027-01-01"),
            habits: [(key("2027-01-01"), days("d", from: "2027-01-01")), (key("2027-01-01"), [])],
            today: key("2027-01-02"), calendar: utc
        )
        #expect(partial[0] == .partial)
    }
}

@Suite("Resolution store")
@MainActor
struct ResolutionStoreTests {
    @Test func oneResolutionAtATimeAndHabitsKeepIt() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let resolution = try context.startResolution(ResolutionDraft(text: "  Sleep better ", templateID: "sleep-better"), startDay: key("2026-12-28"))
        #expect(resolution.text == "Sleep better")
        #expect(resolution.year == 2027)
        #expect(throws: HabitStoreError.resolutionActive) {
            try context.startResolution(ResolutionDraft(text: "Read more"), startDay: key("2026-12-28"))
        }
        #expect(throws: HabitStoreError.invalidResolution(.emptyText)) {
            try context.startResolution(ResolutionDraft(text: "   "), startDay: key("2026-12-28"))
        }

        let template = try #require(try ResolutionLibrary.template(id: "sleep-better"))
        let habits = try template.habits.prefix(2).map {
            try context.addHabit(draft: HabitDraft(template: $0, colorKey: "lilac", packID: template.id, resolutionID: resolution.id))
        }
        #expect(habits[0].cue == "When my alarm for bed goes off")
        #expect(try context.habits(resolutionID: resolution.id).count == 2)

        try context.graduate(habitID: habits[0].id)
        #expect(resolution.state == .active)
        try context.graduate(habitID: habits[1].id)
        #expect(resolution.state == .kept)
        #expect(resolution.keptAt != nil)
        #expect(try context.activeResolution() == nil)

        // A habit coming back to the nest reopens the resolution.
        try context.resume(habitID: habits[1].id)
        #expect(resolution.state == .active)
    }

    @Test func freshStartIsRecorded() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let resolution = try context.startResolution(ResolutionDraft(text: "Move more"), startDay: key("2027-01-01"))
        try context.scheduleFreshStart(resolutionID: resolution.id, on: key("2027-01-18"))
        #expect(resolution.freshStartDayKey == "2027-01-18")
        try context.archiveResolution(id: resolution.id)
        #expect(try context.activeResolution() == nil)
    }
}

@Suite("Migration V1 → V2")
struct MigrationTests {
    @Test func v1StoreOpensWithV2AndKeepsHabitsAndLogs() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("fledge-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("store.sqlite")

        let habitID: UUID
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = ModelContext(container)
            let habit = SchemaV1.Habit(name: "Walk", symbol: "figure.walk", source: .steps, target: 6_000, unit: "steps", slot: 0)
            context.insert(habit)
            context.insert(SchemaV1.DayLog(dayKey: key("2026-10-20"), habit: habit))
            try context.save()
            habitID = habit.id
        }

        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try ModelContainer(
            for: schema, migrationPlan: HabitMigrationPlan.self, configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = ModelContext(container)
        let habit = try #require(try context.habit(id: habitID))
        #expect(habit.name == "Walk")
        #expect(habit.cue == "")
        #expect(habit.resolutionID == nil)
        #expect(habit.logs?.count == 1)
        #expect(try context.activeResolution() == nil)
    }
}

@Suite("MissCheck and cue reminders")
struct MissCheckTests {
    @Test func onlyOneMissedDayCounts() {
        let today = key("2027-01-10")
        #expect(MissCheck.missedOnlyYesterday(snapshots: days("d-", from: "2027-01-08"), perWeek: 7, startedOn: key("2027-01-01"), today: today, calendar: utc))
        #expect(!MissCheck.missedOnlyYesterday(snapshots: days("--", from: "2027-01-08"), perWeek: 7, startedOn: key("2027-01-01"), today: today, calendar: utc))
        #expect(!MissCheck.missedOnlyYesterday(snapshots: days("ds", from: "2027-01-08"), perWeek: 7, startedOn: key("2027-01-01"), today: today, calendar: utc))
        #expect(!MissCheck.missedOnlyYesterday(snapshots: days("d-", from: "2027-01-08"), perWeek: 3, startedOn: key("2027-01-01"), today: today, calendar: utc))
        #expect(!MissCheck.missedOnlyYesterday(snapshots: [], perWeek: 7, startedOn: key("2027-01-09"), today: today, calendar: utc))
    }

    @Test func todayCountsOnceMet() {
        let dots = YearMap.dots(
            from: key("2027-01-01"), through: key("2027-01-02"), startDay: key("2027-01-01"),
            habits: [(key("2027-01-01"), days("-d", from: "2027-01-01"))], today: key("2027-01-02"), calendar: utc
        )
        #expect(dots == [.empty, .full])
    }

    @Test func remindersLeadWithTheCue() {
        let id = UUID()
        let input = ReminderPlan.Input(habitID: id, name: "Walk", reminderMinutes: 13 * 60, todayStatus: .pending, cue: "After lunch")
        #expect(input.reminderTitle == "After lunch: Walk")
        let plain = ReminderPlan.Input(habitID: id, name: "Walk", reminderMinutes: 13 * 60, todayStatus: .pending)
        #expect(plain.reminderTitle == "Walk")
        let now = key("2027-01-10").date(in: utc).addingTimeInterval(-6 * 3600) // 06:00
        let reminders = ReminderPlan.reminders(for: [input], today: key("2027-01-10"), now: now, calendar: utc)
        #expect(reminders.first?.title == "After lunch: Walk")
    }
}

@Suite("Resolution store: attaching habits")
@MainActor
struct ResolutionAttachTests {
    @Test func habitsAddedLaterServeTheActiveResolution() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let before = try context.addHabit(draft: HabitDraft(name: "Read", symbol: "book.fill"))
        #expect(before.resolutionID == nil)
        let resolution = try context.startResolution(ResolutionDraft(text: "Read more"), startDay: key("2027-01-01"))
        let after = try context.addHabit(draft: HabitDraft(name: "Stretch", symbol: "figure.cooldown"))
        #expect(after.resolutionID == resolution.id)
        #expect(before.resolutionID == nil)
    }

    @Test func startingCanAdoptTheNest() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", symbol: "figure.walk"))
        let read = try context.addHabit(draft: HabitDraft(name: "Read", symbol: "book.fill"))
        try context.pause(habitID: read.id)
        let resolution = try context.startResolution(ResolutionDraft(text: "Move more"), startDay: key("2027-01-01"), attachingActiveHabits: true)
        #expect(walk.resolutionID == resolution.id)
        #expect(read.resolutionID == nil)   // paused habits aren't adopted
    }

    @Test func aNewResolutionAdoptsHabitsOfAKeptOne() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let first = try context.startResolution(ResolutionDraft(text: "Move more"), startDay: key("2027-01-01"))
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", symbol: "figure.walk"))
        try context.archiveResolution(id: first.id)
        let second = try context.startResolution(ResolutionDraft(text: "Sleep better"), startDay: key("2027-03-01"), attachingActiveHabits: true)
        #expect(walk.resolutionID == second.id)
    }
}

@Suite("Resolution moments")
struct ResolutionMomentTests {
    private let now = key("2026-12-20").date(in: utc)

    @Test func letterAndWobbleWhileActive() {
        let moments = ReminderPlan.resolutionMoments(
            resolutionText: "Sleep better", year: 2027, startDay: key("2026-12-20"), isActive: true, hasLetter: true, now: now, calendar: utc
        )
        #expect(moments.map(\.identifier) == ["fledge.moment.wobble.2027", "fledge.moment.letter.2027"])
        #expect(DayKey(moments[0].fireDate, calendar: utc, dayEndHour: 0) == key("2027-01-08"))
        #expect(utc.component(.hour, from: moments[0].fireDate) == 10)
        #expect(DayKey(moments[1].fireDate, calendar: utc, dayEndHour: 0) == key("2027-12-01"))
        #expect(moments[1].body.contains("Sleep better"))
    }

    @Test func nothingWhenKeptNoLetterOrStartedLate() {
        #expect(ReminderPlan.resolutionMoments(resolutionText: "x", year: 2027, startDay: key("2026-12-20"), isActive: false, hasLetter: true, now: now, calendar: utc).isEmpty)
        let late = ReminderPlan.resolutionMoments(resolutionText: "x", year: 2027, startDay: key("2027-03-01"), isActive: true, hasLetter: false, now: key("2027-03-01").date(in: utc), calendar: utc)
        #expect(late.isEmpty)
        let past = ReminderPlan.resolutionMoments(resolutionText: "x", year: 2027, startDay: key("2026-12-20"), isActive: true, hasLetter: true, now: key("2027-12-02").date(in: utc), calendar: utc)
        #expect(past.isEmpty)
    }
}

@Suite("YearMap with flown habits")
struct YearMapEndedTests {
    @Test func aFlownHabitLeavesThePlan() {
        let walk = YearMap.Habit(startedOn: key("2027-01-01"), snapshots: days("dddd", from: "2027-01-01"))
        // Read flew on Jan 2 and isn't logged after that.
        let read = YearMap.Habit(startedOn: key("2027-01-01"), endedOn: key("2027-01-02"), snapshots: days("dd", from: "2027-01-01"))
        let dots = YearMap.dots(from: key("2027-01-01"), through: key("2027-01-04"), startDay: key("2027-01-01"), habits: [walk, read], today: key("2027-01-05"), calendar: utc)
        #expect(dots == [.full, .full, .full, .full])
        let year = YearMap.dots(year: 2027, startDay: key("2027-01-01"), habits: [walk, read], today: key("2027-01-05"), calendar: utc)
        #expect(Array(year.prefix(5)) == [.full, .full, .full, .full, .future])
    }
}
