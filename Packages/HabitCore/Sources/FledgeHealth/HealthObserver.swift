import Foundation
import HealthKit

/// Registers `HKObserverQuery`s with background delivery so new Health data wakes the app.
/// Must be started early at launch (Apple requires observers to be set up in `didFinishLaunching`).
public final class HealthObserver: @unchecked Sendable {
    private let reader: HealthReader
    private var queries: [HKObserverQuery] = []
    private let lock = NSLock()

    public init(reader: HealthReader) {
        self.reader = reader
    }

    /// Starts observing `metrics`; `onUpdate` runs for every change and must finish before HealthKit is told it's handled.
    public func start(metrics: [HealthMetric], onUpdate: @escaping @Sendable () async -> Void) {
        guard HealthReader.isAvailable else { return }
        stop()
        let types = Set(metrics.map(\.sampleType))
        var started: [HKObserverQuery] = []
        for type in types {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                let done = CompletionBox(completion)
                guard error == nil else { done.call(); return }
                Task {
                    await onUpdate()
                    done.call()
                }
            }
            reader.store.execute(query)
            started.append(query)
            // Some types (e.g. steps) are delivered at most hourly regardless of the requested frequency.
            reader.store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
        }
        lock.withLock { queries = started }
    }

    public func stop() {
        let current = lock.withLock { () -> [HKObserverQuery] in
            defer { queries = [] }
            return queries
        }
        current.forEach { reader.store.stop($0) }
    }
}

/// Lets HealthKit's non-Sendable completion handler cross into a Task.
private final class CompletionBox: @unchecked Sendable {
    private let completion: HKObserverQueryCompletionHandler
    init(_ completion: @escaping HKObserverQueryCompletionHandler) { self.completion = completion }
    func call() { completion() }
}
