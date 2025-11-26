import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let notificationCenter = UNUserNotificationCenter.current()

    private func dispatchToMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    func ensureAuthorization(completion: ((Bool, UNAuthorizationStatus) -> Void)? = nil) {
        notificationCenter.getNotificationSettings { [weak self] settings in
            guard let self else {
                DispatchQueue.main.async {
                    completion?(false, .notDetermined)
                }
                return
            }
            if self.isAuthorized(status: settings.authorizationStatus) {
                self.dispatchToMain {
                    completion?(true, settings.authorizationStatus)
                }
            } else if settings.authorizationStatus == .notDetermined {
                self.notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    self.dispatchToMain {
                        completion?(granted, granted ? .authorized : .denied)
                    }
                }
            } else {
                self.dispatchToMain {
                    completion?(false, settings.authorizationStatus)
                }
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
            self.dispatchToMain {
                completion(self.isAuthorized(status: settings.authorizationStatus))
            }
        }
    }

    func scheduleReminders(for habit: Habit) {
        cancelReminders(for: habit)

        guard !habit.reminderComponents.isEmpty else { return }

        ensureAuthorization { [weak self] granted, status in
            guard let self else { return }

            guard granted else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .notificationsPermissionDenied,
                        object: nil,
                        userInfo: ["status": status.rawValue]
                    )
                }
                return
            }

            for (index, components) in habit.reminderComponents.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = habit.name
                content.body = "Time for your \(habit.name.lowercased()) habit."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let identifier = self.reminderIdentifier(for: habit, index: index)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                self.notificationCenter.add(request)
            }
        }
    }

    func cancelReminders(for habit: Habit) {
        // Remove current identifiers immediately.
        let currentIdentifiers = habit.reminderComponents.indices.map { reminderIdentifier(for: habit, index: $0) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: currentIdentifiers)

        // Also sweep any stale identifiers that belonged to this habit (e.g., reminders removed by the user).
        let prefix = "habit-\(habit.id.uuidString)"
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let stale = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) && !currentIdentifiers.contains($0) }
            guard !stale.isEmpty else { return }
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: stale)
        }
    }
    
    func cancelAll() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    func clearBadge() {
        notificationCenter.setBadgeCount(0, withCompletionHandler: { _ in })
    }
    
    func rescheduleAll(for habits: [Habit]) {
        ensureAuthorization { granted, _ in
            guard granted else { return }
            for habit in habits where !habit.reminders.isEmpty && !habit.isArchived {
                self.scheduleReminders(for: habit)
            }
        }
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

extension Notification.Name {
    static let notificationsPermissionDenied = Notification.Name("TinyHabits.notificationsPermissionDenied")
}
