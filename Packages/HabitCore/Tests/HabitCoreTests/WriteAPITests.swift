import Foundation
import SwiftData
import Testing
@testable import HabitCore

@Suite("ModelContext write API")
struct WriteAPITests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try SharedStore.makeContainer(inMemory: true))
    }

    @Test func nestHoldsThreeHabits() throws {
        let context = try makeContext()
        let pack = try PackLibrary.essentials()
        for (slot, template) in pack.templates.prefix(3).enumerated() {
            let habit = try context.addHabit(from: template, colorKey: "sky", packID: pack.id)
            #expect(habit.slot == slot)
        }
        #expect(throws: HabitStoreError.nestFull) {
            try context.addHabit(from: pack.templates[3], colorKey: "sky", packID: pack.id)
        }
    }

    @Test func graduatingFreesTheSlot() throws {
        let context = try makeContext()
        let pack = try PackLibrary.essentials()
        let first = try context.addHabit(from: pack.templates[0], colorKey: "dawn", packID: pack.id)
        try context.addHabit(from: pack.templates[1], colorKey: "sky", packID: pack.id)
        try context.addHabit(from: pack.templates[2], colorKey: "meadow", packID: pack.id)

        try context.graduate(habitID: first.id)
        #expect(first.state == .graduated)
        #expect(first.slot == nil)

        let replacement = try context.addHabit(from: pack.templates[3], colorKey: "gold", packID: pack.id)
        #expect(replacement.slot == 0)
        #expect(throws: HabitStoreError.nestFull) { try context.resume(habitID: first.id) }
    }

    @Test func pauseAndResume() throws {
        let context = try makeContext()
        let habit = try context.addHabit(name: "Read", symbol: "book.fill", colorKey: "dawn", source: .manual, target: 1, unit: "times")
        try context.pause(habitID: habit.id)
        #expect(try context.activeHabits().isEmpty)
        try context.resume(habitID: habit.id)
        #expect(habit.state == .active)
        #expect(habit.slot == 0)
    }

    @Test func doneAndUndoOnMainContext() throws {
        let context = try makeContext()
        let habit = try context.addHabit(name: "Read", symbol: "book.fill", colorKey: "dawn", source: .manual, target: 1, unit: "times")
        let day = DayKey(rawValue: "2026-12-15")!
        try context.setDone(true, habitID: habit.id, on: day, by: .manual)
        #expect(try context.log(for: habit.id, on: day)?.status == .done)
        try context.setDone(false, habitID: habit.id, on: day, by: .manual)
        #expect(try context.log(for: habit.id, on: day)?.status == .pending)
        #expect(habit.logs?.count == 1)
    }
}
