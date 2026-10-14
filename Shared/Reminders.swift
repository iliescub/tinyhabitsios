import Foundation
import SwiftData
import UserNotifications
import HabitCore

/// Schedules reminders from `ReminderPlan` (NOTIF-1). Called after every write, Health sync and app activation,
/// so a habit that's already done never gets nudged.
@MainActor
enum Reminders {
    /// Asks once, when the first reminder is turned on.
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func reconcile(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }

        let today = DayKey.today()
        let habits = (try? context.activeHabits()) ?? []
        let inputs = habits.map { habit in
            let log = habit.logs?.first { $0.dayKey == today.rawValue }
            return ReminderPlan.Input(
                habitID: habit.id,
                name: habit.name,
                reminderMinutes: habit.reminderMinutes,
                todayStatus: DayEvaluator.evaluate(
                    value: log?.value ?? 0, target: habit.target, stored: log?.status ?? .pending, completedBy: log?.completedBy
                ).status,
                remainingText: remainingText(for: habit, value: log?.value ?? 0)
            )
        }
        let plan = ReminderPlan.reminders(for: inputs, today: today, now: .now)
            + ReminderPlan.eveningSummaries(minutes: FledgeSettings.eveningSummaryMinutes, habits: inputs, today: today, now: .now)

        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderPlan.identifierPrefix) || $0.hasPrefix(ReminderPlan.summaryIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for reminder in plan {
            await schedule(reminder, in: center)
        }
        await checkFlownHabits(context: context, today: today, center: center)
    }

    /// GRAD-3: one gentle nudge when a flown Health habit falls below 50% over 14 days; none again until it holds (≥ 80%).
    /// The pending nudge survives the rebuild above (different prefix), so a reconcile never cancels it.
    private static func checkFlownHabits(context: ModelContext, today: DayKey, center: UNUserNotificationCenter) async {
        let graduated = HabitState.graduated.rawValue
        let flown = (try? context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { $0.stateRaw == graduated }))) ?? []
        var nudged = FledgeSettings.slipNudgedHabitIDs
        for habit in flown where habit.source.isAuto {
            let since = habit.graduatedAt.map { DayKey($0, dayEndHour: FledgeSettings.dayEndHour) }
            let rate = HoldingRate.rate(snapshots: habit.logs?.compactMap(\.snapshot) ?? [], today: today, since: since)
            let id = habit.id.uuidString
            switch SlipCheck.decide(rate: rate, alreadyNudged: nudged.contains(id)) {
            case .nudge:
                await schedule(ReminderPlan.slipNudge(habitID: habit.id, name: habit.name, now: .now), in: center, route: "flown")
                nudged.insert(id)
            case .rearm:
                nudged.remove(id)
                center.removePendingNotificationRequests(withIdentifiers: [ReminderPlan.slipIdentifierPrefix + id])
            case .none:
                break
            }
        }
        // Forget habits that were brought back, deleted or no longer exist.
        nudged.formIntersection(flown.map(\.id.uuidString))
        FledgeSettings.slipNudgedHabitIDs = nudged
    }

    private static func schedule(_ reminder: ReminderPlan.Reminder, in center: UNUserNotificationCenter, route: String? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.threadIdentifier = reminder.habitID.uuidString
        if let route { content.userInfo = ["route": route] }
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
    }

    /// "1,800 steps to go." for quantity habits; nil for once-a-day habits.
    private static func remainingText(for habit: Habit, value: Double) -> String? {
        guard habit.target > 1, value > 0, value < habit.target else { return nil }
        let left = (habit.target - value).formatted(.number.precision(.fractionLength(0...1)))
        return "\(left) \(habit.unit) to go."
    }
}
