import Foundation
import SwiftData

/// First shipped schema. Rules that keep iCloud sync possible in 1.1:
/// no `.unique` attributes, every property has a default, relationships are optional.
public enum SchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [Habit.self, DayLog.self]
    }

    @Model
    public final class Habit {
        public var id: UUID = UUID()
        public var name: String = ""
        public var symbol: String = "circle"
        public var colorKey: String = "blue"
        public var stateRaw: String = HabitState.active.rawValue
        /// 0...2 while active, nil otherwise.
        public var slot: Int?
        public var sourceRaw: String = HabitSourceID.manual.rawValue
        public var target: Double = 1
        public var unit: String = "times"
        /// 7 = every day; 1...6 = that many days per week.
        public var perWeek: Int = 7
        /// Minutes after midnight, nil = no reminder.
        public var reminderMinutes: Int?
        public var packID: String = "essentials"
        public var startedAt: Date = Date.now
        public var graduatedAt: Date?

        @Relationship(deleteRule: .cascade, inverse: \DayLog.habit)
        public var logs: [DayLog]? = []

        public init(
            name: String,
            symbol: String,
            colorKey: String = "blue",
            source: HabitSourceID = .manual,
            target: Double = 1,
            unit: String = "times",
            perWeek: Int = 7,
            slot: Int? = nil,
            packID: String = "essentials",
            startedAt: Date = .now
        ) {
            self.name = name
            self.symbol = symbol
            self.colorKey = colorKey
            self.sourceRaw = source.rawValue
            self.target = max(target, 0.0001)
            self.unit = unit
            self.perWeek = min(max(perWeek, 1), 7)
            self.slot = slot
            self.packID = packID
            self.startedAt = startedAt
        }

        public var state: HabitState {
            get { HabitState(rawValue: stateRaw) ?? .active }
            set { stateRaw = newValue.rawValue }
        }

        public var source: HabitSourceID {
            get { HabitSourceID(rawValue: sourceRaw) }
            set { sourceRaw = newValue.rawValue }
        }

        public var cadence: Cadence { Cadence(perWeek: perWeek) }
    }

    @Model
    public final class DayLog {
        /// "yyyy-MM-dd", computed with `DayKey` (respects the day-end hour).
        public var dayKey: String = ""
        public var value: Double = 0
        public var statusRaw: String = EntryStatus.pending.rawValue
        public var completedByRaw: String?
        public var updatedAt: Date = Date.now
        public var habit: Habit?

        public init(dayKey: DayKey, habit: Habit) {
            self.dayKey = dayKey.rawValue
            self.habit = habit
        }

        public var status: EntryStatus {
            get { EntryStatus(rawValue: statusRaw) ?? .pending }
            set { statusRaw = newValue.rawValue }
        }

        public var completedBy: CompletedBy? {
            get { completedByRaw.flatMap(CompletedBy.init(rawValue:)) }
            set { completedByRaw = newValue?.rawValue }
        }

        public var snapshot: DaySnapshot? {
            DayKey(rawValue: dayKey).map { DaySnapshot(day: $0, status: status) }
        }
    }
}

public typealias Habit = SchemaV1.Habit
public typealias DayLog = SchemaV1.DayLog

public enum HabitMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
