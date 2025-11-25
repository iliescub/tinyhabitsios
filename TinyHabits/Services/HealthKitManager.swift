import HealthKit
import Foundation

enum HealthAuthorizationResult {
    case granted
    case denied
    case unavailable
}

final class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private init() {}

    func requestAuthorization(completion: @escaping (HealthAuthorizationResult) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(.unavailable)
            return
        }

        var typesToRead: Set<HKObjectType> = [stepsType]
        if let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            typesToRead.insert(heartType)
        }

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { granted, _ in
            DispatchQueue.main.async {
                completion(granted ? .granted : .denied)
            }
        }
    }

    func fetchTodayStepCount(completion: @escaping (Int?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(nil)
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
            guard error == nil else {
                completion(nil)
                return
            }

            if let sum = statistics?.sumQuantity() {
                let total = Int(sum.doubleValue(for: HKUnit.count()))
                completion(total)
            } else {
                completion(0)
            }
        }
        healthStore.execute(query)
    }

    func fetchLatestHeartRate(completion: @escaping (Double?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard error == nil,
                  let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
            completion(bpm)
        }
        healthStore.execute(query)
    }
}
