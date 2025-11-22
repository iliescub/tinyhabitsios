import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    func ensureAuthorization(completion: ((Bool) -> Void)? = nil) {
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self else {
                completion?(false)
                return
            }
            if self.isAuthorized(status: settings.authorizationStatus) {
                completion?(true)
            } else if settings.authorizationStatus == .notDetermined {
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion?(granted)
                }
            } else {
                completion?(false)
            }
        }
    }

    func isAuthorized() async -> Bool {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: self.isAuthorized(status: settings.authorizationStatus))
            }
        }
    }

    func fetchAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            completion(self.isAuthorized(status: settings.authorizationStatus))
        }
    }

    func scheduleReminders(for habit: Habit) {
        cancelReminders(for: habit)

        guard !habit.reminderComponents.isEmpty else { return }

        for (index, components) in habit.reminderComponents.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = habit.name
            content.body = "Time for your \(habit.name.lowercased()) habit."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = reminderIdentifier(for: habit, index: index)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            notificationCenter.add(request)
        }
    }

    func cancelReminders(for habit: Habit) {
        let identifiers = habit.reminderComponents.indices.map { reminderIdentifier(for: habit, index: $0) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func cancelAll() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    func clearBadge() {
        notificationCenter.setBadgeCount(0, withCompletionHandler: { _ in })
    }

    // UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func isAuthorized(status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional:
            return true
        default:
            return false
        }
    }

    private func reminderIdentifier(for habit: Habit, index: Int) -> String {
        "habit-\(habit.id.uuidString)-\(index)"
    }
}
