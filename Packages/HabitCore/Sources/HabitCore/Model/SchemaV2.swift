import Foundation
import SwiftData

/// Resolution relaunch (RES-1): adds `Resolution` and gives habits an if-then cue and the resolution they serve.
/// Same CloudKit rules as V1: no `.unique`, a default on every property, optional relationships. The resolution's
/// text, reason and letter are the user's own words, not Health data.
public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [Habit.self, DayLog.self, Resolution.self]
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
        /// The "if" of the if-then plan, e.g. "After my morning coffee" (RES-4). Empty = no plan.
        public var cue: String = ""
        /// The `Resolution.id` this habit serves; nil for habits added before V2 or outside a resolution.
        public var resolutionID: UUID?

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
            startedAt: Date = .now,
            cue: String = "",
            resolutionID: UUID? = nil
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
            self.cue = cue
            self.resolutionID = resolutionID
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

    /// One resolution a year (RES-1). Its habits point to it with `Habit.resolutionID`; it's kept once all of them flew.
    @Model
    public final class Resolution {
        public var id: UUID = UUID()
        /// The resolution in the user's words, e.g. "Sleep better".
        public var text: String = ""
        /// The resolution template it came from (`ResolutionLibrary`), empty for a custom one.
        public var templateID: String = ""
        /// Why it matters, written at setup (RES-6).
        public var why: String = ""
        /// The letter to December, sealed until `ResolutionYear.letterOpens` or until the resolution is kept.
        public var letter: String = ""
        /// The resolution year, e.g. 2027. A resolution started in December counts for the next year.
        public var year: Int = 0
        /// First day, as "yyyy-MM-dd"; any fresh-start day, not only Jan 1.
        public var startDayKey: String = ""
        public var stateRaw: String = ResolutionState.active.rawValue
        public var keptAt: Date?
        /// The fresh-start day the user last chose after a lapse (RES-5), "yyyy-MM-dd"; empty = never.
        public var freshStartDayKey: String = ""
        public var createdAt: Date = Date.now

        public init(text: String, templateID: String = "", why: String = "", letter: String = "", year: Int, startDay: DayKey) {
            self.text = text
            self.templateID = templateID
            self.why = why
            self.letter = letter
            self.year = year
            self.startDayKey = startDay.rawValue
        }

        public var state: ResolutionState {
            get { ResolutionState(rawValue: stateRaw) ?? .active }
            set { stateRaw = newValue.rawValue }
        }

        public var startDay: DayKey? { DayKey(rawValue: startDayKey) }
    }
}

public enum ResolutionState: String, Codable, Sendable {
    case active
    /// Every habit of the resolution flew.
    case kept
    /// Let go by the user; history stays.
    case archived
}

public typealias Habit = SchemaV2.Habit
public typealias DayLog = SchemaV2.DayLog
public typealias Resolution = SchemaV2.Resolution

public enum HabitMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    /// V1 → V2 only adds a model and properties with defaults.
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}
