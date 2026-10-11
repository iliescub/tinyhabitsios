import Foundation

/// Lifecycle of a habit. Only `.active` habits occupy one of the three slots.
public enum HabitState: String, Codable, Sendable, CaseIterable {
    case active
    case graduated
    case paused
}

/// Stored outcome of a single day.
public enum EntryStatus: String, Codable, Sendable {
    case pending
    case done
    case skipped
}

/// Who or what completed a day. Manual completions are sticky: Health data never undoes them.
public enum CompletedBy: String, Codable, Sendable {
    case manual
    case auto
    case widget
    case intent
}

/// Identifies where a habit's progress comes from.
/// Raw values: `"manual"`, `"hk.<HKQuantityTypeIdentifier suffix>"`, `"hk.workout"` or `"hk.workout.<activity>"`.
public struct HabitSourceID: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let manual = HabitSourceID(rawValue: "manual")
    public static let steps = HabitSourceID(rawValue: "hk.stepCount")
    public static let exerciseMinutes = HabitSourceID(rawValue: "hk.appleExerciseTime")
    public static let workout = HabitSourceID(rawValue: "hk.workout")
    public static let standHours = HabitSourceID(rawValue: "hk.appleStandHour")
    public static let mindfulMinutes = HabitSourceID(rawValue: "hk.mindfulSession")
    public static let sleep = HabitSourceID(rawValue: "hk.sleepAnalysis")
    public static let water = HabitSourceID(rawValue: "hk.dietaryWater")
    public static let daylight = HabitSourceID(rawValue: "hk.timeInDaylight")

    /// True when progress is read from HealthKit rather than tapped in.
    public var isAuto: Bool { rawValue.hasPrefix("hk.") }

    /// The part after `hk.`, e.g. `stepCount` or `workout.traditionalStrengthTraining`.
    public var healthIdentifier: String? {
        isAuto ? String(rawValue.dropFirst(3)) : nil
    }
}

/// The three-slot rule. Kept in one place so the app, widgets and intents agree.
public enum SlotPolicy {
    public static let maxActive = 3

    /// Lowest free slot index, or nil when all three are taken.
    public static func nextFreeSlot(occupied: Set<Int>) -> Int? {
        (0..<maxActive).first { !occupied.contains($0) }
    }
}
