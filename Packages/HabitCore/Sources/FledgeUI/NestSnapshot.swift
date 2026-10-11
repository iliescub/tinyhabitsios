import Foundation
import SwiftData
import HabitCore

/// Everything the widgets, Lock Screen and Siri show about today's nest (docs/DESIGN.md §7).
public struct NestSnapshot: Sendable {
    public struct Item: Identifiable, Sendable {
        public let id: UUID
        public let card: HabitCardModel
        /// When Health last updated this habit's value (auto habits only).
        public let lastUpdated: Date?

        public init(id: UUID, card: HabitCardModel, lastUpdated: Date?) {
            self.id = id
            self.card = card
            self.lastUpdated = lastUpdated
        }
    }

    public let day: DayKey
    public let items: [Item]
    public let locale: Locale

    public init(day: DayKey, items: [Item], locale: Locale = .current) {
        self.day = day
        self.items = items
        self.locale = locale
    }

    /// Reads the active habits from `context` (call on the context's actor).
    public init(context: ModelContext, day: DayKey, dayEndHour: Int = FledgeSettings.dayEndHour, locale: Locale = .current) {
        let habits = (try? context.activeHabits()) ?? []
        self.day = day
        self.locale = locale
        self.items = habits.map { habit in
            let log = habit.logs?.first { $0.dayKey == day.rawValue }
            let card = HabitCardModel(
                name: habit.name, symbol: habit.symbol, colorKey: habit.colorKey, source: habit.source,
                target: habit.target, unit: habit.unit, cadence: habit.cadence,
                startedOn: DayKey(habit.startedAt, dayEndHour: dayEndHour), today: day,
                todayValue: log?.value ?? 0, todayStatus: log?.status ?? .pending, todayCompletedBy: log?.completedBy,
                history: habit.logs?.compactMap(\.snapshot) ?? [], locale: locale
            )
            return Item(id: habit.id, card: card, lastUpdated: habit.source.isAuto ? log?.updatedAt : nil)
        }
    }

    public var doneCount: Int { items.filter { $0.card.progress.status == .done }.count }

    /// "2/3"
    public var countText: String { "\(doneCount)/\(items.count)" }

    /// "Walk 1.8K steps left" for the first unfinished habit with an amount, else its name.
    public var nextUpText: String? {
        guard let next = items.first(where: { $0.card.progress.status == .pending }) else { return nil }
        let card = next.card
        guard card.target > 1 else { return card.name }
        let left = max(0, card.target - card.progress.value)
        let compact = left.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)).locale(locale))
        return "\(card.name) \(compact) \(card.unit) left"
    }

    /// Inline Lock Screen text: "2/3 · Walk 1.8K steps left" or "All 3 done".
    public var inlineText: String {
        if items.isEmpty { return "Add a habit in Fledge" }
        if doneCount == items.count { return items.count == 1 ? "Done for today" : "All \(items.count) done" }
        return [countText, nextUpText].compactMap { $0 }.joined(separator: " · ")
    }

    /// Spoken by Siri: "2 of 3 done. Walk: 4,210 of 6,000 steps."
    public var spokenSummary: String {
        if items.isEmpty { return "Your nest is empty. Add a habit in Fledge." }
        var parts = ["\(doneCount) of \(items.count) done."]
        for item in items where item.card.progress.status == .pending {
            parts.append("\(item.card.name): \(item.card.valueText).")
        }
        return parts.joined(separator: " ")
    }

    /// Oldest Health update among auto habits, for "updated 14 min ago".
    public var oldestHealthUpdate: Date? {
        items.compactMap(\.lastUpdated).min()
    }

    public static let placeholder = NestSnapshot(day: DayKey(.now), items: [])
}
