import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

@main
struct FledgeApp: App {
    /// Never reset the store on failure (CLAUDE.md); show the error instead.
    private let container = Result {
        #if DEBUG
        if DemoData.isEnabled { return try DemoData.makeContainer() }
        #endif
        return try SharedStore.makeContainer()
    }

    init() {
        // Health observers must be registered at launch so background delivery can wake the app.
        #if DEBUG
        if DemoData.isEnabled { return } // keep demo values; don't touch Health
        #endif
        if case .success(let container) = container {
            HealthSync.start(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootView()
                    .modelContainer(container)
                    .tint(FledgeTheme.Palette.skyText)
            case .failure(let error):
                StoreErrorView(error: error)
            }
        }
    }
}

/// Keeps `TodayView` on the current `DayKey`, which changes at the user's day-end hour (3 AM by default).
struct RootView: View {
    @State private var today = DayKey.today()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(FledgeSettings.dayEndHourKey, store: FledgeSettings.defaults) private var dayEndHour = FledgeSettings.defaultDayEndHour

    var body: some View {
        TodayView(day: today)
            .id(today)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
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
