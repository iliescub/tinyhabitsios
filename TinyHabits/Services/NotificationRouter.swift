import Foundation
import UserNotifications

/// Opens the right screen when a notification is tapped (the GRAD-3 slip nudge opens the Flown shelf),
/// and shows Fledge's notifications as banners while the app is open.
@MainActor
@Observable
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    enum Route: String {
        case flown
    }

    /// Set when a notification asked for a screen; Today opens it and clears this.
    var pending: Route?

    func start() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let route = (response.notification.request.content.userInfo["route"] as? String).flatMap(Route.init(rawValue:))
        await MainActor.run { self.pending = route }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
