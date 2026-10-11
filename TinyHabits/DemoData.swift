#if DEBUG
import Foundation
import SwiftData
import HabitCore

/// Launch with `-FledgeDemoData` to run on an in-memory store with sample habits (never touches real data).
enum DemoData {
    static let launchArgument = "-FledgeDemoData"

    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains(launchArgument) }

    /// `-FledgeDemoScreen detail|graduation|add|flown|settings` opens that screen on launch (for screenshots).
    static var screen: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-FledgeDemoScreen"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static func makeContainer() throws -> ModelContainer {
        let container = try SharedStore.makeContainer(inMemory: true)
        try seed(ModelContext(container))
        return container
    }

    private static func seed(_ context: ModelContext) throws {
        let today = DayKey(.now)
        let calendar = Calendar.current

        // One graduate for the Flown shelf.
        let stretch = try context.addHabit(
            name: "Stretch", symbol: "figure.cooldown", colorKey: "lilac", source: .manual, target: 1, unit: "times",
            startedAt: calendar.date(byAdding: .day, value: -80, to: .now) ?? .now
        )
        try context.graduate(habitID: stretch.id, on: calendar.date(byAdding: .day, value: -14, to: .now) ?? .now)

        // Walk: auto, 40 days in, strong history → ready to fly; partly done today.
        let walk = try context.addHabit(
            name: "Walk", symbol: "figure.walk", colorKey: "dawn", source: .steps, target: 6_000, unit: "steps",
            startedAt: calendar.date(byAdding: .day, value: -39, to: .now) ?? .now
        )
        for offset in 1...39 where offset % 9 != 0 {
            try context.setDone(true, habitID: walk.id, on: today.adding(days: -offset), by: .auto)
        }
        try context.record(value: 4_210, habitID: walk.id, on: today, by: .auto)

        // Read: manual, 12 days in, done today.
        let read = try context.addHabit(
            name: "Read", symbol: "book.fill", colorKey: "sky", source: .manual, target: 1, unit: "times",
            startedAt: calendar.date(byAdding: .day, value: -11, to: .now) ?? .now
        )
        try context.setDone(true, habitID: read.id, on: today, by: .manual)

        // Meditate: auto, 3 days in, rest day today.
        let meditate = try context.addHabit(
            name: "Meditate", symbol: "brain.head.profile", colorKey: "meadow", source: .mindfulMinutes, target: 5, unit: "min",
            startedAt: calendar.date(byAdding: .day, value: -2, to: .now) ?? .now
        )
        try context.skip(habitID: meditate.id, on: today)

    }
}
#endif
