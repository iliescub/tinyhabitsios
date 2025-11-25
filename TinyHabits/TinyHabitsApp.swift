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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    @StateObject private var swipeGuard = SwipeGuard()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(PersistenceController.shared.container)
                .environmentObject(swipeGuard)
        }
    }
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var didResetNotifications = false
    @AppStorage("motivation_dailyQuotes") private var showDailyQuotes: Bool = true
    @AppStorage("motivation_haptics") private var enableHaptics: Bool = true
    @AppStorage("profile_imageData") private var storedImageData: Data = Data()
    @Environment(\.modelContext) private var context
    @State private var showQuoteOverlay = true
    @State private var quoteOverlayPresented = false
    @State private var quoteText = MotivationProvider.dailyQuote()

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .overlay(alignment: .center) {
            if showQuoteOverlay && showDailyQuotes {
                DailyQuoteOverlay(quote: quoteText)
                    .transition(.opacity)
            }
        }
        .onAppear {
            resetNotificationsIfNeeded()
            presentQuoteOverlay()
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
    
    private func rescheduleRemindersIfNeeded() {
        guard hasCompletedOnboarding else { return }
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { !$0.isArchived })
        let habits = (try? context.fetch(descriptor)) ?? []
        NotificationManager.shared.rescheduleAll(for: habits)
    }

    private func presentQuoteOverlay() {
        guard !quoteOverlayPresented, showDailyQuotes else { return }
        quoteOverlayPresented = true
        showQuoteOverlay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.35)) {
                showQuoteOverlay = false
            }
        }
    }
}
