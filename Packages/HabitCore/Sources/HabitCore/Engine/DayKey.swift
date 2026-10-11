import Foundation

/// A calendar day as "yyyy-MM-dd". Replaces date-range queries so one habit has exactly one log per day,
/// independent of time zone and daylight-saving changes.
public struct DayKey: RawRepresentable, Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.rawValue = String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// The day `date` belongs to. Times before `dayEndHour` (default 3 AM) count for the previous day.
    public init(_ date: Date, calendar: Calendar = .current, dayEndHour: Int = 3) {
        let shifted = calendar.date(byAdding: .hour, value: -dayEndHour, to: date) ?? date
        let parts = calendar.dateComponents([.year, .month, .day], from: shifted)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Noon of this day, a safe anchor for calendar arithmetic.
    public func date(in calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    public func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        let moved = calendar.date(byAdding: .day, value: days, to: date(in: calendar)) ?? date(in: calendar)
        return DayKey(moved, calendar: calendar, dayEndHour: 0)
    }

    /// Whole days from `self` to `other` (positive when `other` is later).
    public func days(to other: DayKey, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: date(in: calendar), to: other.date(in: calendar)).day ?? 0
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String { rawValue }
}
