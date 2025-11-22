import Foundation
import SwiftUI

struct CuratedHabit: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let color: AccentTheme
    let defaultTarget: Int

    init(id: String? = nil, name: String, icon: String, color: AccentTheme, defaultTarget: Int = 1) {
        self.id = id ?? name
        self.name = name
        self.icon = icon
        self.color = color
        self.defaultTarget = max(1, defaultTarget)
    }

    static let onboardingOptions: [CuratedHabit] = [
        CuratedHabit(name: "Drink Water", icon: "drop.fill", color: .blue, defaultTarget: 2000),
        CuratedHabit(name: "Stretch", icon: "figure.cooldown", color: .green, defaultTarget: 5),
        CuratedHabit(name: "Read 10 Minutes", icon: "book.fill", color: .orange, defaultTarget: 30),
        CuratedHabit(name: "Walk", icon: "figure.walk", color: .green, defaultTarget: 5000),
        CuratedHabit(name: "Meditate", icon: "sparkles", color: .blue, defaultTarget: 20)
    ]
}
