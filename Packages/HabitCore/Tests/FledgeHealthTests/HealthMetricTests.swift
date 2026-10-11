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
