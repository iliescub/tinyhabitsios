import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            // Local notifications do not require registering for remote notifications.
        }
    }

    func scheduleDailyReminder(for habit: Habit) {
        guard let components = habit.reminderComponents() else { return }

        let content = UNMutableNotificationContent()
        content.title = habit.name
        content.body = "Time for your \(habit.name.lowercased()) habit."
        content.sound = .default

        var triggerDate = DateComponents()
        triggerDate.hour = components.hour
        triggerDate.minute = components.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
        let identifier = "habit-\(habit.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminder(for habit: Habit) {
        let identifier = "habit-\(habit.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
