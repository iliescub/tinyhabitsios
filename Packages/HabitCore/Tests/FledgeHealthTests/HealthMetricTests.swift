import Testing
import HealthKit
import HabitCore
@testable import FledgeHealth

@Suite("HealthMetric mapping")
struct HealthMetricTests {
    @Test func everyEssentialsAutoTemplateMaps() throws {
        let pack = try PackLibrary.essentials()
        for template in pack.templates where template.source.isAuto {
            #expect(HealthMetric(source: template.source, unit: template.unit) != nil, "\(template.name)")
        }
    }

    @Test func specificMappings() {
        #expect(HealthMetric(source: .steps, unit: "steps") == .quantity(.stepCount, unit: "count"))
        #expect(HealthMetric(source: .water, unit: "L") == .quantity(.dietaryWater, unit: "L"))
        #expect(HealthMetric(source: .sleep, unit: "h") == .sleepHours)
        #expect(HealthMetric(source: .workout, unit: "workout") == .workouts(activity: nil, minutes: false))
        #expect(
            HealthMetric(source: HabitSourceID(rawValue: "hk.workout.traditionalStrengthTraining"), unit: "min")
                == .workouts(activity: .traditionalStrengthTraining, minutes: true)
        )
        #expect(HealthMetric(source: .manual, unit: "times") == nil)
        #expect(HealthMetric(source: HabitSourceID(rawValue: "hk.unknownThing"), unit: "x") == nil)
    }
}

@Suite("HealthKit wrappers without Health data", .timeLimit(.minutes(1)))
struct HealthWrapperTests {
    private let metrics: [HealthMetric] = [
        .quantity(.stepCount, unit: "count"), .mindfulMinutes, .standHours, .sleepHours,
        .workouts(activity: nil, minutes: false), .workouts(activity: .running, minutes: true),
    ]

    @Test func everyMetricHasASampleType() {
        #expect(HealthMetric.quantity(.stepCount, unit: "count").sampleType == HKQuantityType(.stepCount))
        #expect(HealthMetric.mindfulMinutes.sampleType == HKCategoryType(.mindfulSession))
        #expect(HealthMetric.standHours.sampleType == HKCategoryType(.appleStandHour))
        #expect(HealthMetric.sleepHours.sampleType == HKCategoryType(.sleepAnalysis))
        #expect(HealthMetric.workouts(activity: nil, minutes: false).sampleType == HKWorkoutType.workoutType())
    }

    @Test func authorizationWithNothingToAskReturnsAtOnce() async throws {
        try await HealthReader().requestAuthorization(for: [])
    }

    @Test func readsEndInAValueOrAnErrorNeverAHang() async {
        // Without Health data on this Mac (or without authorization) each read throws or returns zero.
        let reader = HealthReader()
        let day = DayKey(year: 2027, month: 1, day: 10)
        for metric in metrics {
            if let value = try? await reader.value(for: metric, on: day, dayEndHour: 3) {
                #expect(value >= 0)
            }
            _ = await reader.hasRecentSamples(for: metric)
        }
    }

    @Test func observerStartsAndStopsSafely() {
        let observer = HealthObserver(reader: HealthReader())
        observer.start(metrics: metrics) {}
        observer.stop()
        observer.stop()
    }
}
