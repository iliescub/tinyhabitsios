import Foundation

// The three features behind "the habit tracker that lets go" (docs/POSITIONING.md):
// a head start from the user's own Health history (HEAD-1), a slip check after a habit flew (GRAD-3),
// and a forecast of the day a habit can fly (GRAD-4). Pure, so they're tested without HealthKit.

/// The last 30 days of a Health metric, read when a habit is added (HEAD-1). Read on the device; only the
/// daily values the app already keeps per day are stored.
public struct HealthBaseline: Equatable, Sendable {
    public enum Verdict: Equatable, Sendable {
        /// Fewer than 7 days with any data: no advice (no iPhone or Watch data for this metric).
        case notEnoughData
        /// Met on at least 80% of days: it's already a habit, so suggest a bigger goal or something new.
        case alreadyHabit
        /// Met on at least half the days: the goal is within reach as it is.
        case withinReach
        /// Met on fewer than half the days: suggest a smaller first goal, just above the usual level.
        case startSmaller
    }

    public static let days = 30
    public static let minimumDaysWithData = 7

    /// Days with any data (a zero usually means no device was carried, so it isn't averaged in).
    public let daysWithData: Int
    /// Average over the days with data.
    public let average: Double
    /// Days on which `target` was met.
    public let daysMet: Int
    public let target: Double
    public let verdict: Verdict
    /// A goal to offer instead of `target`; nil when the current goal is right or there isn't enough data.
    public let suggestedTarget: Double?

    /// - Parameters:
    ///   - values: one value per day for the 30 days before today, oldest first.
    ///   - step, range: the goal stepper's increment and limits for this unit, so suggestions land on round numbers.
    public init(values: [Double], target: Double, step: Double, range: ClosedRange<Double>, rule: GraduationRule = .standard) {
        let recorded = values.filter { $0 > 0 }
        daysWithData = recorded.count
        average = recorded.isEmpty ? 0 : recorded.reduce(0, +) / Double(recorded.count)
        daysMet = values.filter { $0 >= target && $0 > 0 }.count
        self.target = target

        func roundedUp(_ value: Double) -> Double {
            let rounded = (value / step).rounded(.up) * step
            return min(max(rounded, range.lowerBound), range.upperBound)
        }

        let metRate = Double(daysMet) / Double(max(values.count, 1))
        if daysWithData < Self.minimumDaysWithData {
            verdict = .notEnoughData
            suggestedTarget = nil
        } else if metRate >= rule.threshold {
            verdict = .alreadyHabit
            let bigger = max(roundedUp(average * 1.2), roundedUp(target + step))
            suggestedTarget = bigger > target ? bigger : nil
        } else if metRate >= 0.5 {
            verdict = .withinReach
            suggestedTarget = nil
        } else {
            verdict = .startSmaller
            // Just above the usual level, on the stepper's grid (nearest step, so it doesn't round back up to the goal).
            let nearest = (average * 1.1 / step).rounded() * step
            let smaller = min(max(nearest, range.lowerBound), range.upperBound)
            suggestedTarget = smaller < target && smaller > 0 ? smaller : nil
        }
    }
}

/// Whether a flown habit has slipped enough for its one nudge (GRAD-3). Spec: "If one drops below 50% over 14 days,
/// the app sends a single gentle nudge." After a nudge, nothing more until the habit is holding again (≥ 80%).
public enum SlipCheck {
    public enum Decision: Equatable, Sendable {
        /// Send the nudge now.
        case nudge
        /// Holding again: allow a future nudge.
        case rearm
        case none
    }

    public static func decide(rate: Double?, alreadyNudged: Bool) -> Decision {
        guard let rate else { return .none }
        if !alreadyNudged && rate < HoldingRate.slipping { return .nudge }
        if alreadyNudged && rate >= HoldingRate.strong { return .rearm }
        return .none
    }
}

extension ReminderPlan {
    public static let slipIdentifierPrefix = "fledge.slip."

    /// The slip nudge: an hour from now between 9:00 and 19:00, otherwise at 10:00 the next morning.
    public static func slipNudge(habitID: UUID, name: String, now: Date, calendar: Calendar = .current) -> Reminder {
        let hour = calendar.component(.hour, from: now)
        let fire: Date
        if (9..<19).contains(hour) {
            fire = now.addingTimeInterval(3_600)
        } else {
            let morning = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now
            fire = hour < 9 ? morning : calendar.date(byAdding: .day, value: 1, to: morning) ?? morning
        }
        return Reminder(
            identifier: "\(slipIdentifierPrefix)\(habitID.uuidString)",
            habitID: habitID,
            fireDate: fire,
            title: name,
            body: "\(name) has slipped a little since it flew. Bring it back to the nest for a while?"
        )
    }
}

/// The day a habit can fly if it's met every day from tomorrow on (GRAD-4). Nil when it's ready already, or when
/// even that wouldn't get it there within `horizon` days.
public enum FlightForecast {
    public static func flyDate(
        snapshots: [DaySnapshot],
        cadence: Cadence,
        startedOn: DayKey,
        today: DayKey,
        rule: GraduationRule = .standard,
        horizon: Int = 120,
        calendar: Calendar = .current
    ) -> DayKey? {
        if GraduationEvaluator.status(snapshots: snapshots, cadence: cadence, startedOn: startedOn, today: today, rule: rule, calendar: calendar).isReady {
            return nil
        }
        var future = snapshots.filter { $0.day <= today }
        // Today counts as done too if it isn't over yet: the forecast assumes the habit is kept from now on.
        if !future.contains(where: { $0.day == today && $0.status != .pending }) {
            future.removeAll { $0.day == today }
            future.append(DaySnapshot(day: today, status: .done))
        }
        for offset in 1...horizon {
            let day = today.adding(days: offset, calendar: calendar)
            future.append(DaySnapshot(day: day, status: .done))
            let status = GraduationEvaluator.status(snapshots: future, cadence: cadence, startedOn: startedOn, today: day, rule: rule, calendar: calendar)
            if status.isReady { return day }
        }
        return nil
    }
}

extension FledgeSettings {
    public static let slipNudgedKey = "slipNudgedHabitIDs"

    /// Flown habits that already got their slip nudge (GRAD-3); cleared per habit once it holds again.
    public static var slipNudgedHabitIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: slipNudgedKey) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: slipNudgedKey) }
    }
}
