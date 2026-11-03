import Foundation
import SwiftData

/// What the user types or picks when starting a resolution (onboarding step 1, RES-9).
public struct ResolutionDraft: Equatable, Sendable {
    public static let maxTextLength = 40
    public static let maxWhyLength = 280
    public static let maxLetterLength = 2_000

    public var text: String
    public var templateID: String
    public var why: String
    public var letter: String

    public init(text: String = "", templateID: String = "", why: String = "", letter: String = "") {
        self.text = text
        self.templateID = templateID
        self.why = why
        self.letter = letter
    }

    public var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// A reason or letter of only spaces and newlines counts as none.
    public var trimmedWhy: String { why.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var trimmedLetter: String { letter.trimmingCharacters(in: .whitespacesAndNewlines) }

    public enum Problem: Error, Equatable, Sendable {
        case emptyText
        case textTooLong
        case whyTooLong
        case letterTooLong
    }

    public var problem: Problem? {
        if trimmedText.isEmpty { return .emptyText }
        if trimmedText.count > Self.maxTextLength { return .textTooLong }
        if why.count > Self.maxWhyLength { return .whyTooLong }
        if letter.count > Self.maxLetterLength { return .letterTooLong }
        return nil
    }
}

/// Resolution part of the write API (RES-1). Same rules as the habit writes: main context in the app, then
/// `AppRefresh.afterWrite`.
extension ModelContext {
    /// The resolution in progress, if any. There is at most one.
    public func activeResolution() throws -> Resolution? {
        let active = ResolutionState.active.rawValue
        let descriptor = FetchDescriptor<Resolution>(
            predicate: #Predicate { $0.stateRaw == active },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try fetch(descriptor).first
    }

    public func resolution(id: UUID) throws -> Resolution? {
        try fetch(FetchDescriptor<Resolution>(predicate: #Predicate { $0.id == id })).first
    }

    /// Every resolution, newest year first (the Kept shelf).
    public func allResolutions() throws -> [Resolution] {
        try fetch(FetchDescriptor<Resolution>(sortBy: [SortDescriptor(\.year, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]))
    }

    public func habits(resolutionID: UUID) throws -> [Habit] {
        try fetch(FetchDescriptor<Habit>(predicate: #Predicate { $0.resolutionID == resolutionID }))
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// Starts a resolution on `startDay` (any day; `ResolutionYear` picks the year). Throws `.resolutionActive`
    /// while another one is in progress.
    /// - Parameter attachingActiveHabits: also link the habits already in the nest that serve no resolution
    ///   (users coming from Fledge, or a new resolution after one was kept or let go).
    @discardableResult
    public func startResolution(_ draft: ResolutionDraft, startDay: DayKey, attachingActiveHabits: Bool = false) throws -> Resolution {
        if let problem = draft.problem { throw HabitStoreError.invalidResolution(problem) }
        guard try activeResolution() == nil else { throw HabitStoreError.resolutionActive }
        let resolution = Resolution(
            text: draft.trimmedText, templateID: draft.templateID, why: draft.trimmedWhy, letter: draft.trimmedLetter,
            year: ResolutionYear.year(startingOn: startDay), startDay: startDay
        )
        insert(resolution)
        if attachingActiveHabits {
            let open = try activeHabits().filter { habit in
                guard let id = habit.resolutionID else { return true }
                return (try? self.resolution(id: id))?.state != .active
            }
            for habit in open { habit.resolutionID = resolution.id }
        }
        try save()
        return resolution
    }

    public func updateResolution(id: UUID, with draft: ResolutionDraft) throws {
        if let problem = draft.problem { throw HabitStoreError.invalidResolution(problem) }
        guard let resolution = try resolution(id: id) else { throw HabitStoreError.resolutionNotFound }
        resolution.text = draft.trimmedText
        resolution.templateID = draft.templateID
        resolution.why = draft.trimmedWhy
        resolution.letter = draft.trimmedLetter
        try save()
    }

    /// Lets the resolution go without keeping it; its habits stay as they are.
    public func archiveResolution(id: UUID) throws {
        guard let resolution = try resolution(id: id) else { throw HabitStoreError.resolutionNotFound }
        resolution.state = .archived
        try save()
    }

    /// Records the fresh-start day the user chose after a lapse (RES-5). History and graduation progress stay.
    public func scheduleFreshStart(resolutionID: UUID, on day: DayKey) throws {
        guard let resolution = try resolution(id: resolutionID) else { throw HabitStoreError.resolutionNotFound }
        resolution.freshStartDayKey = day.rawValue
        try save()
    }

    /// Marks the resolution kept once every one of its habits flew; reopens it if one comes back to the nest.
    /// Called by `graduate` and `resume`; doesn't save.
    func updateKeptState(resolutionID: UUID?, on date: Date) throws {
        guard let resolutionID, let resolution = try resolution(id: resolutionID), resolution.state != .archived else { return }
        let states = try habits(resolutionID: resolutionID).map(\.state)
        if KeptCheck.isKept(habitStates: states) {
            if resolution.state != .kept {
                resolution.state = .kept
                resolution.keptAt = date
            }
        } else if resolution.state == .kept, try activeResolution() == nil {
            resolution.state = .active
            resolution.keptAt = nil
        }
    }
}
