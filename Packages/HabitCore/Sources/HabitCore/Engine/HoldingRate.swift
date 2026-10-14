import Foundation

/// How well a graduated habit is holding up on its own (spec: "Graduated habits keep tracking quietly. If one drops
/// below 50% over 14 days, the app sends a single gentle nudge"). Shown on the Flown shelf (UX-14).
public enum HoldingRate {
    /// Days looked at.
    public static let window = 14
    /// At or above this, the shelf shows the rate in gold.
    public static let strong = 0.8
    /// Below this, the habit is slipping (the nudge threshold).
    public static let slipping = 0.5

    /// Share of the `window` days before `today` that were done. Today is left out because it isn't over yet.
    /// Rest days count as met, the same as for streaks. Days before `since` (the graduation day) are not counted,
    /// so a habit that flew a week ago is judged on that week only. Nil when there is no day to judge yet.
    public static func rate(
        snapshots: [DaySnapshot], today: DayKey, since: DayKey? = nil, window: Int = window, calendar: Calendar = .current
    ) -> Double? {
        let days = judgedDays(today: today, since: since, window: window, calendar: calendar)
        guard !days.isEmpty else { return nil }
        let met = metDays(snapshots)
        return Double(days.filter(met.contains).count) / Double(days.count)
    }

    /// One point per day for the sparkline: the rate over the 7 days ending that day (fewer at the start),
    /// for the `window` days before today.
    public static func trend(
        snapshots: [DaySnapshot], today: DayKey, window: Int = window, smoothing: Int = 7, calendar: Calendar = .current
    ) -> [Double] {
        let met = metDays(snapshots)
        return (1...window).reversed().map { offset in
            let end = today.adding(days: -offset, calendar: calendar)
            let span = (0..<smoothing).map { end.adding(days: -$0, calendar: calendar) }
            return Double(span.filter(met.contains).count) / Double(smoothing)
        }
    }

    private static func judgedDays(today: DayKey, since: DayKey?, window: Int, calendar: Calendar) -> [DayKey] {
        (1...max(window, 1)).map { today.adding(days: -$0, calendar: calendar) }.filter { day in
            since.map { day >= $0 } ?? true
        }
    }

    private static func metDays(_ snapshots: [DaySnapshot]) -> Set<DayKey> {
        Set(snapshots.filter { $0.status == .done || $0.status == .skipped }.map(\.day))
    }
}
