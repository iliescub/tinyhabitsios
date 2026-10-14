import Foundation
import HabitCore

/// HEAD-1, the Health head start: what the last 30 days say about a habit before it starts, and the backfill after it's added.
@MainActor
enum HeadStart {
    /// Asks for read access (the system sheet appears only once), then reads the 30 days before today.
    /// Nil for tap-to-log habits, without Apple Health, or when there's nothing to read.
    static func values(source: HabitSourceID, unit: String) async -> [Double]? {
        #if DEBUG
        if DemoData.isEnabled { return DemoData.baselineValues(for: source) }
        #endif
        guard source.isAuto, DeviceInfo.isHealthAvailable, let sync = HealthSync.shared else { return nil }
        _ = await sync.prepare(source: source, unit: unit)
        return await sync.baselineValues(source: source, unit: unit)
    }

    /// Fills the 30 days before a new Health habit from Apple Health ("Before Fledge" on the heatmap).
    static func backfill(_ habit: Habit) async {
        #if DEBUG
        if DemoData.isEnabled { return }
        #endif
        guard habit.source.isAuto else { return }
        await HealthSync.shared?.backfill(habitID: habit.id, source: habit.source, unit: habit.unit)
    }
}

/// What the head-start section in the habit editor shows.
enum HeadStartState: Equatable {
    case none
    case loading
    case values([Double])
}
