import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

@main
struct FledgeApp: App {
    @State private var store = AppModel()

    var body: some Scene {
        WindowGroup {
            switch store.container {
            case .success(let container):
                RootView(onBecameActive: store.reloadIfChangedElsewhere)
                    .modelContainer(container)
                    .tint(FledgeTheme.Palette.skyText)
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}

/// Owns the ModelContainer. Widgets and Siri write from other processes; when they did,
/// the container is reopened on activation so every view shows their changes.
@MainActor
@Observable
final class AppModel {
    /// Never reset the store on failure (CLAUDE.md); show the error instead.
    private(set) var container: Result<ModelContainer, Error>
    private var seenExternalWrite: Date

    init() {
        container = Self.makeContainer()
        Purchases.shared.start()
        seenExternalWrite = FledgeSettings.lastExternalWrite ?? .distantPast
        #if DEBUG
        if DemoData.isEnabled { return } // keep demo values; don't touch Health
        #endif
        // Health observers must be registered at launch so background delivery can wake the app.
        if case .success(let container) = container {
            HealthSync.start(container: container)
        }
    }

    func reloadIfChangedElsewhere() {
        #if DEBUG
        if DemoData.isEnabled { return }
        #endif
        guard let last = FledgeSettings.lastExternalWrite, last > seenExternalWrite else { return }
        seenExternalWrite = last
        container = Self.makeContainer()
        if case .success(let container) = container {
            HealthSync.shared?.use(container: container)
        }
    }

    private static func makeContainer() -> Result<ModelContainer, Error> {
        Result {
            #if DEBUG
            if DemoData.isEnabled { return try DemoData.makeContainer() }
            #endif
            return try SharedStore.makeContainer()
        }
    }
}

/// Keeps `TodayView` on the current `DayKey`, which changes at the user's day-end hour (3 AM by default).
struct RootView: View {
    let onBecameActive: () -> Void
    @State private var today = DayKey.today()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Query private var allHabits: [Habit]
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(FledgeSettings.dayEndHourKey, store: FledgeSettings.defaults) private var dayEndHour = FledgeSettings.defaultDayEndHour

    var body: some View {
        if Self.forcesOnboarding || (!hasCompletedOnboarding && allHabits.isEmpty && !Self.skipsOnboarding) {
            OnboardingView { hasCompletedOnboarding = true }
        } else {
            today_
        }
    }

    /// DEBUG: `-FledgeDemoScreen onboarding[-pick|-health|-reminders]` always shows onboarding (at that step).
    private static var forcesOnboarding: Bool {
        #if DEBUG
        return DemoData.isEnabled && (DemoData.screen?.hasPrefix("onboarding") ?? false)
        #else
        return false
        #endif
    }

    /// DEBUG: demo data and screenshots skip onboarding unless `-FledgeDemoScreen onboarding`.
    private static var skipsOnboarding: Bool {
        #if DEBUG
        return DemoData.isEnabled && !(DemoData.screen?.hasPrefix("onboarding") ?? false)
        #else
        return false
        #endif
    }

    private var today_: some View {
        TodayView(day: today)
            .id(today)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                onBecameActive()
                refreshDay()
                Task { await HealthSync.shared?.refresh() }
            }
            .onChange(of: dayEndHour) { _, _ in refreshDay() }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    refreshDay()
                }
            }
    }

    private func refreshDay() {
        let now = DayKey.today()
        if now != today { today = now }
    }
}

struct StoreErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("Fledge can't open its data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Your habits are safe on this iPhone. Please restart the app or update it.\n\n\(error.localizedDescription)")
        }
    }
}
