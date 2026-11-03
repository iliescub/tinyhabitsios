import Foundation

/// Editable fields of a habit, used by the Add and Edit screens. Validated before it reaches the store.
public struct HabitDraft: Equatable, Sendable {
    public static let maxNameLength = 30

    public var name: String
    public var symbol: String
    public var colorKey: String
    public var source: HabitSourceID
    public var target: Double
    public var unit: String
    public var perWeek: Int
    /// Minutes after midnight, nil = no reminder.
    public var reminderMinutes: Int?
    public var packID: String
    /// The "if" of the if-then plan (RES-4), e.g. "After my morning coffee". Empty = no plan.
    public var cue: String
    /// The resolution this habit serves.
    public var resolutionID: UUID?

    public static let maxCueLength = 40

    public init(
        name: String = "",
        symbol: String = "star.fill",
        colorKey: String = "sky",
        source: HabitSourceID = .manual,
        target: Double = 1,
        unit: String = "times",
        perWeek: Int = 7,
        reminderMinutes: Int? = nil,
        packID: String = "essentials",
        cue: String = "",
        resolutionID: UUID? = nil
    ) {
        self.name = name
        self.symbol = symbol
        self.colorKey = colorKey
        self.source = source
        self.target = target
        self.unit = unit
        self.perWeek = perWeek
        self.reminderMinutes = reminderMinutes
        self.packID = packID
        self.cue = cue
        self.resolutionID = resolutionID
    }

    public init(template: Pack.Template, colorKey: String, packID: String, resolutionID: UUID? = nil) {
        self.init(
            name: template.name, symbol: template.symbol, colorKey: colorKey, source: template.source,
            target: template.target, unit: template.unit, perWeek: template.perWeek ?? 7, packID: packID,
            cue: template.cue ?? "", resolutionID: resolutionID
        )
    }

    public init(habit: Habit) {
        self.init(
            name: habit.name, symbol: habit.symbol, colorKey: habit.colorKey, source: habit.source,
            target: habit.target, unit: habit.unit, perWeek: habit.perWeek,
            reminderMinutes: habit.reminderMinutes, packID: habit.packID, cue: habit.cue,
            resolutionID: habit.resolutionID
        )
    }

    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedCue: String {
        cue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public enum Problem: Error, Equatable, Sendable {
        case emptyName
        case nameTooLong
        case cueTooLong
        case targetNotPositive
        case invalidReminder
    }

    /// First problem found, or nil when the draft can be saved.
    public var problem: Problem? {
        if trimmedName.isEmpty { return .emptyName }
        if trimmedName.count > Self.maxNameLength { return .nameTooLong }
        if trimmedCue.count > Self.maxCueLength { return .cueTooLong }
        if !(target > 0) { return .targetNotPositive }
        if let minutes = reminderMinutes, !(0..<(24 * 60)).contains(minutes) { return .invalidReminder }
        return nil
    }
}
