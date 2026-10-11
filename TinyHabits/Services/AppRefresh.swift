import AppIntents
import WidgetKit
import SwiftData
import HabitCore

/// What has to happen after the app writes: widgets, controls and Siri phrases see the new state,
/// and reminders are rebuilt.
@MainActor
enum AppRefresh {
    static func afterWrite(context: ModelContext, structural: Bool = false) {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
        if structural {
            FledgeShortcuts.updateAppShortcutParameters()
            HealthSync.shared?.updateObservers()
        } else {
            Task { await Reminders.reconcile(context: context) }
        }
    }
}

/// Siri and Shortcuts phrases (INT-2). Every phrase must contain the app name.
struct FledgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CompleteHabitIntent(),
            phrases: [
                "Mark \(\.$habit) done in \(.applicationName)",
                "Complete \(\.$habit) in \(.applicationName)",
            ],
            shortTitle: "Mark Done",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: HabitStatusIntent(),
            phrases: [
                "How are my habits in \(.applicationName)",
                "\(.applicationName) status",
            ],
            shortTitle: "Habit Status",
            systemImageName: "bird"
        )
        AppShortcut(
            intent: SkipTodayIntent(),
            phrases: [
                "Rest day for \(\.$habit) in \(.applicationName)",
            ],
            shortTitle: "Rest Day",
            systemImageName: "moon.zzz"
        )
    }
}
