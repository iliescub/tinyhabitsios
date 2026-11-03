import Foundation
import Testing
import HabitCore
@testable import FledgeUI

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func key(_ raw: String) -> DayKey { DayKey(rawValue: raw)! }

@Suite("ResolutionHeaderModel")
struct ResolutionHeaderModelTests {
    @Test func headStartBeforeTheYear() {
        let model = ResolutionHeaderModel(
            text: "Sleep better", templateSentence: "sleeping better", year: 2027, startDay: key("2026-11-20"),
            isKept: false, habits: [(key("2026-11-20"), [], .active), (key("2026-11-20"), [], .active)],
            today: key("2026-12-01"), calendar: utc
        )
        #expect(model.sentence == "In 2027 I'm sleeping better")
        #expect(model.progressLine == "Head start · 31 days to 2027 · 0 of 2 flown")
        #expect(model.dots.count == 365)
        #expect(model.dots.allSatisfy { $0 == .future })
    }

    @Test func duringTheYearCountsDaysAndFlown() {
        let walk: [DaySnapshot] = [DaySnapshot(day: key("2027-01-01"), status: .done), DaySnapshot(day: key("2027-01-02"), status: .done)]
        let model = ResolutionHeaderModel(
            text: "Learn the cello", templateSentence: nil, year: 2027, startDay: key("2026-12-20"),
            isKept: false, habits: [(key("2026-12-20"), walk, .graduated), (key("2026-12-20"), [], .active), (key("2026-12-20"), [], .paused)],
            today: key("2027-01-12"), calendar: utc
        )
        #expect(model.sentence == "My 2027 resolution: Learn the cello")
        #expect(model.progressLine == "Day 12 of 365 · 1 of 3 flown")   // a paused habit still has to fly
        #expect(model.dots[0] == .partial)
        #expect(model.dotsSummary == "Year map: 0 days with every habit met, 2 with some.")
    }

    @Test func keptSaysSo() {
        let model = ResolutionHeaderModel(
            text: "Move more", templateSentence: "moving more", year: 2027, startDay: key("2027-01-01"),
            isKept: true, habits: [(key("2027-01-01"), [], .graduated)], today: key("2027-04-01"), calendar: utc
        )
        #expect(model.progressLine == "Kept · every habit flew")
    }
}

@Suite("ResolutionHeaderModel first week")
struct FirstWeekTests {
    @Test func firstSevenDaysShowTheFirstWeek() {
        let walk = [DaySnapshot(day: key("2027-01-01"), status: .done), DaySnapshot(day: key("2027-01-03"), status: .done)]
        let model = ResolutionHeaderModel(
            text: "Move more", templateSentence: "moving more", why: "  For the kids ", year: 2027, startDay: key("2027-01-01"),
            isKept: false, habits: [(key("2027-01-01"), walk, .active)], today: key("2027-01-03"), calendar: utc
        )
        #expect(model.isFirstWeek)
        #expect(model.why == "For the kids")
        #expect(model.progressLine == "First week · day 3 of 7 · 0 of 1 flown")
        #expect(model.firstWeekDays.first == key("2027-01-01"))
        #expect(model.firstWeekDots == [.full, .empty, .full, .future, .future, .future, .future])
    }

    @Test func dayEightShowsTheYear() {
        let model = ResolutionHeaderModel(
            text: "Move more", templateSentence: "moving more", year: 2027, startDay: key("2027-01-01"),
            isKept: false, habits: [(key("2027-01-01"), [], .active)], today: key("2027-01-08"), calendar: utc
        )
        #expect(!model.isFirstWeek)
        #expect(model.progressLine == "Day 8 of 365 · 0 of 1 flown")
    }
}

@Suite("YearGridModel")
struct YearGridModelTests {
    @Test func splitsTheYearIntoMonths() {
        var dots = Array(repeating: YearMap.Dot.future, count: 365)
        dots[0] = .full          // Jan 1
        dots[31] = .partial      // Feb 1
        dots[59] = .full         // Mar 1 (2027 isn't a leap year)
        dots[364] = .empty       // Dec 31
        let grid = YearGridModel(year: 2027, dots: dots, calendar: utc)
        #expect(grid.months.map(\.dots.count) == [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31])
        #expect(grid.months[0].dots[0] == .full)
        #expect(grid.months[1].dots[0] == .partial)
        #expect(grid.months[2].dots[0] == .full)
        #expect(grid.months[11].dots[30] == .empty)
        #expect(grid.fullDays == 2)
        #expect(grid.metDays == 3)
        #expect(grid.months[1].metDays == 1 && grid.months[1].fullDays == 0)
    }

    @Test func leapYearsAndShortInput() {
        let leap = YearGridModel(year: 2028, dots: Array(repeating: .empty, count: 366), calendar: utc)
        #expect(leap.months[1].dots.count == 29)
        let short = YearGridModel(year: 2027, dots: Array(repeating: .full, count: 40), calendar: utc)
        #expect(short.months[0].dots.count == 31)
        #expect(short.months[1].dots.count == 9)
        #expect(short.months[2].dots.isEmpty)
    }
}

@Suite("FlownGroups")
struct FlownGroupsTests {
    struct Item: Equatable { let name: String; let resolution: UUID? }

    @Test func groupsByResolutionNewestYearFirst() {
        let a = UUID(), b = UUID(), gone = UUID()
        let items = [Item(name: "Walk", resolution: a), Item(name: "Read", resolution: b), Item(name: "Stretch", resolution: nil),
                     Item(name: "Sleep", resolution: b), Item(name: "Old", resolution: gone)]
        let infos: [UUID: FlownGroups.ResolutionInfo] = [
            a: .init(text: "Move more", year: 2026, isKept: true, createdAt: .distantPast),
            b: .init(text: "Read more", year: 2027, isKept: false, createdAt: .now),
        ]
        let groups = FlownGroups.groups(items, resolutionID: \.resolution, resolutions: infos)
        #expect(groups.map(\.title) == ["Read more · 2027", "Move more · 2026 · Kept", "Other habits"])
        #expect(groups[0].items.map(\.name) == ["Read", "Sleep"])
        #expect(groups[2].items.map(\.name) == ["Stretch", "Old"])
    }

    @Test func noResolutionsMeansNoHeaders() {
        let groups = FlownGroups.groups([Item(name: "Walk", resolution: nil)], resolutionID: \.resolution, resolutions: [:])
        #expect(groups.count == 1)
        #expect(groups[0].title == nil)
        #expect(FlownGroups.groups([Item](), resolutionID: \.resolution, resolutions: [:]).isEmpty)
    }

    @Test func sameYearNewestFirst() {
        let a = UUID(), b = UUID()
        let infos: [UUID: FlownGroups.ResolutionInfo] = [
            a: .init(text: "First", year: 2027, isKept: false, createdAt: Date(timeIntervalSince1970: 0)),
            b: .init(text: "Second", year: 2027, isKept: false, createdAt: Date(timeIntervalSince1970: 100)),
        ]
        let groups = FlownGroups.groups([Item(name: "x", resolution: a), Item(name: "y", resolution: b)], resolutionID: \.resolution, resolutions: infos)
        #expect(groups.map(\.title) == ["Second · 2027", "First · 2027"])
    }
}

@Suite("ResolutionHeaderModel with flown habits")
struct HeaderEndedTests {
    private func habits(_ walk: [DaySnapshot]) -> [(startedOn: DayKey, endedOn: DayKey?, snapshots: [DaySnapshot], state: HabitState)] {
        [(key("2027-01-01"), nil, walk, .active), (key("2027-01-01"), key("2027-01-05"), [], .graduated)]
    }

    @Test func flownHabitsDontMakeDaysPartial() {
        let walk = [DaySnapshot(day: key("2027-01-10"), status: .done)]
        let model = ResolutionHeaderModel(
            text: "Move more", templateSentence: nil, year: 2027, startDay: key("2027-01-01"), isKept: false,
            habits: habits(walk),
            today: key("2027-01-11"), calendar: utc
        )
        #expect(model.dots[9] == .full)       // Jan 10: Walk done, Stretch already flew
        #expect(model.progressLine == "Day 11 of 365 · 1 of 2 flown")
    }
}


@Suite("ResolutionHeaderModel from stored models")
@MainActor
struct HeaderFromModelsTests {
    @Test func buildsFromAResolutionAndItsHabits() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let other = try context.addHabit(draft: HabitDraft(name: "Old", symbol: "star.fill"), startedAt: key("2026-12-01").date(in: utc))
        let resolution = try context.startResolution(ResolutionDraft(text: "Sleep better", templateID: "sleep-better", why: " Rest "), startDay: key("2027-01-01"))
        let sleep = try context.addHabit(draft: HabitDraft(name: "Sleep", symbol: "bed.double.fill", perWeek: 7), startedAt: key("2027-01-01").date(in: utc))
        let lift = try context.addHabit(draft: HabitDraft(name: "Lift", symbol: "dumbbell.fill", perWeek: 3), startedAt: key("2027-01-01").date(in: utc))
        try context.setDone(true, habitID: sleep.id, on: key("2027-01-04"), by: .manual)
        try context.pause(habitID: lift.id)
        let model = try #require(ResolutionHeaderModel(resolution: resolution, habits: [other, sleep, lift], today: key("2027-01-10"), dayEndHour: 0, calendar: utc))
        #expect(model.sentence == "In 2027 I'm sleeping better")
        #expect(model.why == "Rest")
        #expect(model.progressLine == "Day 10 of 365 · 0 of 2 flown")
        #expect(model.dots[3] == .full)        // Jan 4: Sleep done; Lift is paused, so off the map
        #expect(model.dots[4] == .empty)

        resolution.startDayKey = ""
        #expect(ResolutionHeaderModel(resolution: resolution, habits: [sleep], today: key("2027-01-10")) == nil)
    }

    @Test func storedHabitMapsWithItsCadenceAndFlight() throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let habit = try context.addHabit(draft: HabitDraft(name: "Lift", symbol: "dumbbell.fill", perWeek: 3), startedAt: key("2027-01-01").date(in: utc))
        try context.graduate(habitID: habit.id, on: key("2027-02-01").date(in: utc))
        let mapped = YearMap.Habit(habit, dayEndHour: 0, calendar: utc)
        #expect(mapped.startedOn == key("2027-01-01"))
        #expect(mapped.endedOn == key("2027-02-01"))
        #expect(mapped.perWeek == 3)
    }
}
