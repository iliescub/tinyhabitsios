import Foundation
import SwiftData
import Testing
@testable import HabitCore

@Suite("HabitWriter")
struct HabitWriterTests {
    private func makeHabit(in container: ModelContainer, target: Double) throws -> UUID {
        let context = ModelContext(container)
        let habit = Habit(name: "Walk", symbol: "figure.walk", source: .steps, target: target, unit: "steps", slot: 0)
        context.insert(habit)
        try context.save()
        return habit.id
    }

    private func status(of id: UUID, on day: DayKey, in container: ModelContainer) throws -> (EntryStatus, CompletedBy?) {
        let key = day.rawValue
        let logs = try ModelContext(container).fetch(FetchDescriptor<DayLog>(predicate: #Predicate { $0.dayKey == key && $0.habit?.id == id }))
        #expect(logs.count == 1)
        return (logs.first?.status ?? .pending, logs.first?.completedBy)
    }

    @Test func healthValueCompletesHabitAndKeepsOneLogPerDay() async throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let id = try makeHabit(in: container, target: 6_000)
        let writer = HabitWriter(modelContainer: container)
        let today = DayKey(rawValue: "2026-12-15")!

        try await writer.record(value: 2_000, habitID: id, on: today, by: .auto)
        try await writer.record(value: 6_500, habitID: id, on: today, by: .auto)

        let (status, by) = try status(of: id, on: today, in: container)
        #expect(status == .done)
        #expect(by == .auto)
    }

    @Test func manualDoneSurvivesLowerHealthValue() async throws {
        let container = try SharedStore.makeContainer(inMemory: true)
        let id = try makeHabit(in: container, target: 6_000)
        let writer = HabitWriter(modelContainer: container)
        let today = DayKey(rawValue: "2026-12-15")!

        try await writer.setDone(true, habitID: id, on: today, by: .widget)
        try await writer.record(value: 300, habitID: id, on: today, by: .auto)

        let (status, by) = try status(of: id, on: today, in: container)
        #expect(status == .done)
        #expect(by == .widget)
    }
}
