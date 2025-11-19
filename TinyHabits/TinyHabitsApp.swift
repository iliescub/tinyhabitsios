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
//            Habit.self,
//            HabitEntry.self
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
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                //                MainTabView()
            } else {
                //                OnboardingView()
            }
        }
    }
}
