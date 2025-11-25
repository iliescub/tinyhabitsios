//
//  MainTabView.swift
//  TinyHabits
//
//  Created by Bogdan Iliescu on 19.11.2025.
//

import Foundation
import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var swipeGuard: SwipeGuard
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.order, order: .forward)
    private var habits: [Habit]

    @State private var selectedTab: Int = 0

    private let tabCount = 4
    private var dragThreshold: CGFloat { 50 }

    init() {}
    var body: some View {
        TabView(selection: $selectedTab) {
            FocusView(habits: Array(habits))
                .tabItem {
                    Label("Focus", systemImage: "checkmark.circle")
                }
                .tag(0)

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
        .coordinateSpace(name: "MainTabSpace")
        .highPriorityGesture(
            DragGesture(minimumDistance: dragThreshold, coordinateSpace: .named("MainTabSpace"))
                .onEnded { value in
                    let translation = value.translation
                    guard abs(translation.width) > abs(translation.height) else { return }
                    guard !isLocationBlocked(value.startLocation) else { return }
                    handleSwipe(translation.width)
                }
        )
    }

    private func handleSwipe(_ translation: CGFloat) {
        guard abs(translation) > dragThreshold else { return }
        let direction = translation < 0 ? 1 : -1
        let nextIndex = (selectedTab + direction + tabCount) % tabCount
        withAnimation {
            selectedTab = nextIndex
        }
    }

    private func isLocationBlocked(_ location: CGPoint) -> Bool {
        swipeGuard.blockedRegions.contains { $0.contains(location) }
    }
}
