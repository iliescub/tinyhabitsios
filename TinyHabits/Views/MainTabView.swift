import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.order, order: .forward)
    private var habits: [Habit]

    @State private var selectedTab: Int = 0
    init() {}
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(habits: Array(habits.prefix(3)))
                .tabItem {
                    Label("Today", systemImage: "checkmark.circle")
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
        }
    }
}

