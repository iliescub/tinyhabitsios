//
//  TinyHabitsApp.swift
//  TinyHabits
//
//  Created by Bogdan Iliescu on 19.11.2025.
//

import SwiftUI
import SwiftData

@main
struct TinyHabitsApp: App {
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            HabitEntry.self
        ])

        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(sharedModelContainer)
        }
    }
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var didResetNotifications = false
    @AppStorage("motivation_dailyQuotes") private var showDailyQuotes: Bool = true
    @AppStorage("motivation_haptics") private var enableHaptics: Bool = true
    @AppStorage("profile_imageData") private var storedImageData: Data = Data()
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            resetNotificationsIfNeeded()
        }
    }
    
    private func resetNotificationsIfNeeded() {
        guard !didResetNotifications, !hasCompletedOnboarding else { return }
        didResetNotifications = true
        NotificationManager.shared.cancelAll()
        // Reset local toggles so UI stays in sync with cleared notifications.
        showDailyQuotes = false
        enableHaptics = true
        storedImageData = Data()
    }
}
