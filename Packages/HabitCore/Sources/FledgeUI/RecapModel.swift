import Foundation
import HabitCore

/// The graduation recap and share card (UX-12, UX-13): the numbers that say a habit stuck.
public struct RecapModel: Equatable, Sendable {
    public enum Day: Equatable, Sendable {
        case done, rest, open
    }

    /// "40"
    public let daysText: String
    /// "87%"
    public let rateText: String
    /// "21"
    public let bestText: String
    /// "days", "weeks"
    public let bestUnit: String
    /// "Started 5 Sep · 6,000 steps a day"
    public let footnote: String
    /// The last 30 days, oldest first.
    public let strip: [Day]

    public init(
        stats: HabitDetailStats, snapshots: [DaySnapshot], startedOn: DayKey, today: DayKey,
        target: Double, unit: String, perWeek: Int, locale: Locale = .current, calendar: Calendar = .current
    ) {
        daysText = "\(stats.graduation.daysActive)"
        rateText = "\(Int((stats.graduation.recentRate * 100).rounded()))%"
        bestText = "\(stats.streak.best)"
        bestUnit = stats.streak.unit == .days ? (stats.streak.best == 1 ? "day" : "days") : (stats.streak.best == 1 ? "week" : "weeks")

        let template = Pack.Template(name: "", symbol: "", source: .manual, target: target, unit: unit, perWeek: perWeek)
        let started = startedOn.date(in: calendar).formatted(.dateTime.day().month(.abbreviated).locale(locale))
        footnote = "Started \(started) · \(TemplateStyle.targetText(for: template, locale: locale))"

        let byDay = Dictionary(snapshots.map { ($0.day, $0.status) }, uniquingKeysWith: { _, last in last })
        strip = (0..<30).reversed().map { offset in
            switch byDay[today.adding(days: -offset, calendar: calendar)] {
            case .done: .done
            case .skipped: .rest
            default: .open
            }
        }
    }
}
