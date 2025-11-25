import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        let schema = Self.modelSchema
        let configuration = ModelConfiguration(url: Self.storeURL)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    private static var storeURL: URL {
        let manager = FileManager.default
        let appSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("TinyHabits", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("TinyHabitsModel.sqlite")
    }

    private static var modelSchema: Schema {
        Schema([
            Habit.self,
            HabitEntry.self
        ])
    }
}
