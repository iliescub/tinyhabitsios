import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()
    static let migrationResetFlagKey = "TinyHabits.migrationReset"

    let container: ModelContainer

    private init() {
        let schema = Self.modelSchema
        let configuration = ModelConfiguration(url: Self.storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            UserDefaults.standard.set(true, forKey: Self.migrationResetFlagKey)
            // Attempt a non-destructive migration by backing up the old store, then recreate.
            if let backupURL = try? Self.backupPersistentStore() {
                print("SwiftData migration: backed up incompatible store to \(backupURL.lastPathComponent)")
            } else {
                print("SwiftData migration: failed to backup existing store, proceeding with reset.")
            }

            try? Self.resetPersistentStore()

            do {
                container = try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to initialize ModelContainer after migration/reset: \(error)")
            }
        }
    }

    private static var storeURL: URL {
        let manager = FileManager.default
        guard let appSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate application support directory")
        }
        let directory = appSupport.appendingPathComponent("TinyHabits", isDirectory: true)
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("TinyHabitsModel.sqlite")
    }

    private static func storeFileURLs() -> [URL] {
        let sqlite = storeURL
        let shm = sqlite.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let wal = sqlite.deletingPathExtension().appendingPathExtension("sqlite-wal")
        return [sqlite, shm, wal]
    }

    private static func backupPersistentStore() throws -> URL {
        let manager = FileManager.default
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDirectory = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Backups", isDirectory: true)
        try? manager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let backupBase = backupDirectory.appendingPathComponent("TinyHabitsModel-\(timestamp)")
        var finalBackupURL: URL?

        for url in storeFileURLs() {
            guard manager.fileExists(atPath: url.path) else { continue }
            let backupURL = backupBase.appendingPathExtension(url.pathExtension)
            try manager.copyItem(at: url, to: backupURL)
            finalBackupURL = backupURL
        }

        if let finalBackupURL {
            return finalBackupURL
        } else {
            throw NSError(domain: "TinyHabits.Persistence", code: 1, userInfo: [NSLocalizedDescriptionKey: "No store files to backup"])
        }
    }

    private static func resetPersistentStore() throws {
        let manager = FileManager.default
        for url in storeFileURLs() {
            try? manager.removeItem(at: url)
        }
    }

    private static var modelSchema: Schema {
        Schema([
            Habit.self,
            HabitEntry.self
        ])
    }
}
