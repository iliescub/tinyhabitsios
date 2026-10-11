import Foundation
import HealthKit
import HabitCore

/// How a `HabitSourceID` is read from HealthKit and reduced to one daily number in the habit's unit.
public enum HealthMetric: Hashable, Sendable {
    /// Cumulative quantity, e.g. steps, exercise minutes, water, daylight.
    case quantity(HKQuantityTypeIdentifier, unit: String)
    /// Minutes of mindful sessions.
    case mindfulMinutes
    /// Hours in which the Watch recorded "stood".
    case standHours
    /// Hours of the main sleep session of the night before.
    case sleepHours
    /// Workouts, optionally of one activity type; counted, or summed in minutes.
    case workouts(activity: HKWorkoutActivityType?, minutes: Bool)

    public init?(source: HabitSourceID, unit: String) {
        guard let identifier = source.healthIdentifier else { return nil }
        switch identifier {
        case "stepCount": self = .quantity(.stepCount, unit: "count")
        case "appleExerciseTime": self = .quantity(.appleExerciseTime, unit: "min")
        case "dietaryWater": self = .quantity(.dietaryWater, unit: "L")
        case "timeInDaylight": self = .quantity(.timeInDaylight, unit: "min")
        case "dietaryProtein": self = .quantity(.dietaryProtein, unit: "g")
        case "distanceWalkingRunning": self = .quantity(.distanceWalkingRunning, unit: "km")
        case "flightsClimbed": self = .quantity(.flightsClimbed, unit: "count")
        case "mindfulSession": self = .mindfulMinutes
        case "appleStandHour": self = .standHours
        case "sleepAnalysis": self = .sleepHours
        default:
            guard identifier == "workout" || identifier.hasPrefix("workout.") else { return nil }
            let activityName = identifier.split(separator: ".").dropFirst().first.map(String.init)
            self = .workouts(activity: activityName.flatMap(Self.activity(named:)), minutes: unit == "min")
        }
    }

    /// The HealthKit type to request read access for and to observe.
    public var sampleType: HKSampleType {
        switch self {
        case .quantity(let identifier, _): HKQuantityType(identifier)
        case .mindfulMinutes: HKCategoryType(.mindfulSession)
        case .standHours: HKCategoryType(.appleStandHour)
        case .sleepHours: HKCategoryType(.sleepAnalysis)
        case .workouts: HKWorkoutType.workoutType()
        }
    }

    /// Activity names usable in pack JSON as `hk.workout.<name>`.
    static func activity(named name: String) -> HKWorkoutActivityType? {
        switch name {
        case "traditionalStrengthTraining": .traditionalStrengthTraining
        case "functionalStrengthTraining": .functionalStrengthTraining
        case "running": .running
        case "walking": .walking
        case "cycling": .cycling
        case "swimming": .swimming
        case "yoga": .yoga
        case "highIntensityIntervalTraining": .highIntensityIntervalTraining
        case "pilates": .pilates
        default: nil
        }
    }
}
