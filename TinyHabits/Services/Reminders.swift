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

        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderPlan.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        for reminder in plan {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = reminder.habitID.uuidString
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
        }
    }

    /// "1,800 steps to go." for quantity habits; nil for once-a-day habits.
    private static func remainingText(for habit: Habit, value: Double) -> String? {
        guard habit.target > 1, value > 0, value < habit.target else { return nil }
        let left = (habit.target - value).formatted(.number.precision(.fractionLength(0...1)))
        return "\(left) \(habit.unit) to go."
    }
}
