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
    @AppStorage(PersistenceController.migrationResetFlagKey) private var dataResetDueToMigration: Bool = false
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var showQuoteOverlay = true
    @State private var quoteOverlayPresented = false
    @State private var quoteText = MotivationProvider.dailyQuote()
    @State private var showMigrationWarning = false

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
                DailyQuoteOverlay(quote: quoteText, onDismiss: {
                    hideQuoteOverlay()
                })
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if showMigrationWarning {
                migrationBanner
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            resetNotificationsIfNeeded()
            presentQuoteOverlay()
            if dataResetDueToMigration {
                showMigrationWarning = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                showQuoteAfterForeground()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            showQuoteAfterForeground()
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
            hideQuoteOverlay()
        }
    }

    private func showQuoteAfterForeground() {
        quoteOverlayPresented = false
        quoteText = MotivationProvider.dailyQuote()
        presentQuoteOverlay()
    }

    private func hideQuoteOverlay() {
        withAnimation(.easeOut(duration: 0.35)) {
            showQuoteOverlay = false
        }
    }

    private var migrationBanner: some View {
        ErrorBanner(message: "We had to reset your TinyHabits data after an update. Please re-create your habits. Tap to dismiss.")
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showMigrationWarning = false
                    dataResetDueToMigration = false
                }
            }
    }
}
