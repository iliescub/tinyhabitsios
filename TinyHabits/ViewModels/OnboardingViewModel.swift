import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
final class OnboardingViewModel: ObservableObject {
    private var context: ModelContext?

    @Published var selectedHabits: [CuratedHabit] = []
    @Published var customHabitName: String = ""
    @Published var customHabitTarget: Int = 1
    @Published var profileName: String = ""
    @Published var profileAge: Int = 30
    @Published var profileHeight: Int = 170
    @Published var profileWeight: Int = 70
    @Published var accentSliderValue: Double = 0
    @Published var showingSaveError = false
    @Published var showingProfileValidation = false

    func setContext(_ context: ModelContext) {
        self.context = context
    }

    func canCompleteOnboarding(accentThemes: [AccentTheme], storedAccentTheme: String) -> Bool {
        isProfileComplete && hasSelectedHabits && accentIndex(accentThemes: accentThemes, stored: storedAccentTheme) != nil
    }

    func save(accentThemes: [AccentTheme], storedAccentTheme: String) {
        guard let context else { return }
        guard canCompleteOnboarding(accentThemes: accentThemes, storedAccentTheme: storedAccentTheme) else {
            showingProfileValidation = true
            return
        }

        let accentTheme = AccentTheme(rawValue: storedAccentTheme) ?? .blue

        for (index, habit) in selectedHabits.prefix(3).enumerated() {
            let model = Habit(
                name: habit.name,
                iconSystemName: habit.icon,
                accentColorKey: habit.color.rawValue,
                order: index,
                dailyTarget: habit.defaultTarget
            )
            context.insert(model)
        }

        let trimmedName = customHabitName.trimmingCharacters(in: .whitespaces)
        let createdCount = min(selectedHabits.count, 3)
        if !trimmedName.isEmpty && createdCount < 3 {
            let model = Habit(
                name: trimmedName,
                iconSystemName: "circle",
                accentColorKey: accentTheme.rawValue,
                order: createdCount,
                dailyTarget: customHabitTarget
            )
            context.insert(model)
        }

        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            showingSaveError = true
        }
    }

    func toggleSelection(_ habit: CuratedHabit) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            if let index = selectedHabits.firstIndex(of: habit) {
                selectedHabits.remove(at: index)
            } else if selectedHabits.count < 3 {
                selectedHabits.append(habit)
            }
        }
    }

    func accentIndex(accentThemes: [AccentTheme], stored: String) -> Int? {
        accentThemes.firstIndex { $0.rawValue == stored }
    }

    private var hasSelectedHabits: Bool {
        !selectedHabits.isEmpty || !customHabitName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isProfileComplete: Bool {
        !profileName.trimmingCharacters(in: .whitespaces).isEmpty && profileAge >= 13
    }
}
