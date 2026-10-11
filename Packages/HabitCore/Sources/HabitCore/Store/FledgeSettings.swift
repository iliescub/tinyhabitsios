import Foundation

/// Settings shared by the app, widgets and intents through the App Group's UserDefaults.
public enum FledgeSettings {
    public static let dayEndHourKey = "dayEndHour"
    public static let defaultDayEndHour = 3
    public static let dayEndHourRange = 0...5

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard
    }

    /// Hour (0–5) at which "today" ends; completions before it count for the previous day.
    public static var dayEndHour: Int {
        get {
            let stored = defaults.object(forKey: dayEndHourKey) as? Int ?? defaultDayEndHour
            return min(max(stored, dayEndHourRange.lowerBound), dayEndHourRange.upperBound)
        }
        set {
            defaults.set(min(max(newValue, dayEndHourRange.lowerBound), dayEndHourRange.upperBound), forKey: dayEndHourKey)
        }
    }
}

extension DayKey {
    /// "Today" using the user's day-end hour.
    public static func today(now: Date = .now, calendar: Calendar = .current) -> DayKey {
        DayKey(now, calendar: calendar, dayEndHour: FledgeSettings.dayEndHour)
    }
}

/// Daily habits get two free rest days per calendar month; weekly-cadence habits rest whenever they like.
public enum RestDayPolicy {
    public static let freePassesPerMonth = 2

    /// Rest days still available in `day`'s month, or nil when unlimited (weekly cadence).
    public static func remaining(snapshots: [DaySnapshot], cadence: Cadence, on day: DayKey) -> Int? {
        guard cadence.isDaily else { return nil }
        let used = snapshots.filter { snapshot -> Bool in
            guard snapshot.status == .skipped, snapshot.day != day else { return false }
            return snapshot.day.year == day.year && snapshot.day.month == day.month
        }.count
        return max(0, freePassesPerMonth - used)
    }
}
