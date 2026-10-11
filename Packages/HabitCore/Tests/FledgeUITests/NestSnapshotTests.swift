import Foundation
import SwiftData
import Testing
import HabitCore
@testable import FledgeUI

@Suite("NestSnapshot")
struct NestSnapshotTests {
    private let us = Locale(identifier: "en_US")

    @Test func textsForWidgetsAndSiri() throws {
        let context = ModelContext(try SharedStore.makeContainer(inMemory: true))
        let day = DayKey(rawValue: "2026-12-15")!
        let walk = try context.addHabit(draft: HabitDraft(name: "Walk", source: .steps, target: 6_000, unit: "steps"))
        let read = try context.addHabit(draft: HabitDraft(name: "Read"))
        try context.record(value: 4_200, habitID: walk.id, on: day, by: .auto)
        try context.setDone(true, habitID: read.id, on: day, by: .manual)

        let snapshot = NestSnapshot(context: context, day: day, dayEndHour: 3, locale: us)
        #expect(snapshot.items.map(\.card.name) == ["Walk", "Read"])
        #expect(snapshot.countText == "1/2")
        #expect(snapshot.inlineText == "1/2 · Walk 1.8K steps left")
        #expect(snapshot.spokenSummary == "1 of 2 done. Walk: 4,200 / 6,000 steps.")
        #expect(snapshot.oldestHealthUpdate != nil)

        try context.record(value: 6_100, habitID: walk.id, on: day, by: .auto)
        let done = NestSnapshot(context: context, day: day, dayEndHour: 3, locale: us)
        #expect(done.inlineText == "All 2 done")
    }

    @Test func emptyNest() {
        #expect(NestSnapshot.placeholder.inlineText == "Add a habit in Fledge")
    }
}
