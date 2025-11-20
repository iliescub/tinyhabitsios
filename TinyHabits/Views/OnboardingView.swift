//
//  OnboardingView.swift
//  TinyHabits
//
//  Created by Bogdan Iliescu on 19.11.2025.
//

import Foundation
import SwiftUI
import SwiftData
import UIKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
//    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("profile_name") private var storedName: String = ""
    @AppStorage("profile_age") private var storedAge: Int = 30
    @AppStorage("profile_heightCm") private var storedHeightCm: Int = 170
    @AppStorage("profile_weightKg") private var storedWeightKg: Int = 70
    @AppStorage("accentTheme") private var storedAccentTheme: String = AccentTheme.blue.rawValue
//    @AppStorage("profile_restingHR") private var storedRestingHR: Int = 65
//    @AppStorage("profile_activityLevel") private var storedActivityLevel: Double = 3
//    @AppStorage("profile_goalRaw") private var storedGoalRaw: String = ActivityGoal.balance.rawValue
//    @AppStorage("profile_notes") private var storedNotes: String = ""
    
    @State private var selectedHabits: [CuratedHabit] = []
    @State private var customHabitName: String = ""
    @State private var customHabitTarget: Int = 1
    @Namespace private var habitSelectionNamespace
    @State private var heroAnimate = false
    @State private var showingSaveError = false
    @State private var profileName: String = ""
    @State private var profileAge: Int = 30
    @State private var profileHeight: Int = 170
    @State private var profileWeight: Int = 70
    @State private var accentSliderValue: Double = 0
//    @State private var profileRestingHR: Int = 65
//    @State private var profileActivityLevel: Double = 3
//    @State private var profileGoal: ActivityGoal = .balance
//    @State private var profileNotes: String = ""
//    @State private var didSeedProfileState = false
    @State private var step: OnboardingStep = .profile
    @State private var showingProfileValidation = false
    
    private var accentThemes: [AccentTheme] { AccentTheme.allCases }
    private var accentTheme: AccentTheme {
    AccentTheme(rawValue: storedAccentTheme) ?? .blue
    }
    
    private let curated: [CuratedHabit] = CuratedHabit.onboardingOptions
    private var themeManager = ThemeManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                        .padding(.top, 12)

                    stepContent
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.15),
                        Color.purple.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .onAppear {
            syncAccentSlider()
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) {
                heroAnimate = true
            }
//            seedProfileStateIfNeeded()
        }
        .alert("Something Went Wrong", isPresented: $showingSaveError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("We couldn't save your habits. Please try again after restarting the app.")
        })
        .alert("Complete Your Profile", isPresented: $showingProfileValidation, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("Add your name and age before picking habits.")
        })
        .onChange(of: storedAccentTheme) { _, _ in
            syncAccentSlider()
        }
    }

    private var themeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.headline)
                .foregroundStyle(themeManager.accent.color.opacity(0.8))
            Slider(
                value: Binding(
                    get: { accentSliderValue },
                    set: { newValue in
                        accentSliderValue = newValue
                        updateAccentTheme(with: newValue)
                    }
                ),
                in: 0...Double(max(accentThemes.count - 1, 1)),
                step: 1
            )
//            HStack(spacing: 12) {
//                ForEach(Array(accentThemes.enumerated()), id: \.element.id) { index, theme in
//                    Circle()
//                        .fill(theme.color)
//                        .frame(width: 28, height: 28)
//                        .overlay(
//                            Circle()
//                                .stroke(
//                                    index == Int(accentSliderValue.rounded()) ? Color.primary : .clear,
//                                    lineWidth: 2
//                                )
//                        )
//                        .accessibilityLabel(Text(theme.rawValue.capitalized))
//                }
//            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: themeManager.accent.color.opacity(0.2), radius: 8, y: 4)
    }
    

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.complementary1AccentVariant,
                            themeManager.complementary2AccentVariant
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
//                .overlay(
//                    Circle()
//                        .fill(.white.opacity(0.2))
//                        .scaleEffect(heroAnimate ? 1.1 : 0.8)
//                        .offset(x: heroAnimate ? 40 : -20, y: heroAnimate ? -30 : -60)
//                        .blur(radius: 20)
//                )
//                .overlay(
//                    Circle()
//                        .strokeBorder(.white.opacity(0.3), lineWidth: 3)
//                        .scaleEffect(heroAnimate ? 0.35 : 0.2)
//                        .offset(x: heroAnimate ? 100 : 30, y: heroAnimate ? -60 : -10)
//                )
            


            VStack(alignment: .leading, spacing: 10) {
                Text("TinyHabits")
                    .font(.largeTitle.bold())
                    .foregroundStyle(themeManager.accent.color
                    .opacity(heroAnimate ? 1 : 0.6))
                Text("Pick up to 3 habits to focus on daily.")
                    .foregroundStyle(themeManager.accent.color.opacity(0.8))
                    .font(.headline)
                
                heroImageView
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)
                    .padding(.vertical, 8)
                    .offset(y: heroAnimate ? -4 : 10)
                Spacer(minLength: 0)
                
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(themeManager.accent.color.opacity(0.8))
                        .scaleEffect(heroAnimate ? 1 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).repeatForever(autoreverses: true), value: heroAnimate)
                    Text("Small steps. Big change.")
                        .foregroundStyle(themeManager.accent.color.opacity(0.8))
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .shadow(color: themeManager.accent.color.opacity(0.4), radius: 12, y: 8)
    }
    
    @ViewBuilder
    private var heroImageView: some View {
        if UIImage(named: AssetNames.onboardingHero) != nil {
            Image(AssetNames.onboardingHero)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
            Image(systemName: "figure.run")
                .resizable()
                .scaledToFit()
                .foregroundStyle(themeManager.accent.color.opacity(0.8))
                .accessibilityLabel("Running illustration")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
    case .profile:
            themeSelector

            profileStepView

        case .habits:
            habitsStepView
        }
    }
    
    private var profileStepView: some View {
        VStack(spacing: 20) {
            profileSection

            Button {
                guard isProfileComplete else {
                    showingProfileValidation = true
                    return
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    step = .habits
                }
            } label: {
                Text("Continue to Habits")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                themeManager.complementary1AccentVariant,
                                themeManager.complementary2AccentVariant
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(themeManager.accent.color.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .purple.opacity(0.2), radius: 15, y: 8)
            }
        }
    }
    
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Your Profile")
                .font(.headline)
                .foregroundStyle(themeManager.accent.color.opacity(0.8))

            TextField("Full name", text: $profileName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .foregroundStyle(themeManager.accent.color.opacity(0.8))
            Stepper("Age: \(profileAge)", value: $profileAge, in: 13...100)
                .foregroundStyle(themeManager.accent.color.opacity(0.8))

            VStack(alignment: .leading, spacing: 8) {
                Text("Physical Details")
                    .font(.subheadline)
                
                Stepper("Height: \(profileHeight) cm", value: $profileHeight, in: 120...230)
                Stepper("Weight: \(profileWeight) kg", value: $profileWeight, in: 40...200)
//                Stepper("Resting HR: \(profileRestingHR) bpm", value: $profileRestingHR, in: 40...120)
            }
            .foregroundStyle(themeManager.accent.color.opacity(0.8))

//            VStack(alignment: .leading, spacing: 8) {
//                Picker("Primary focus", selection: $profileGoal) {
//                    ForEach(ActivityGoal.allCases) { goal in
//                        Text(goal.title).tag(goal)
//                    }
//                }
//                Text(profileGoal.description)
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }

//            VStack(alignment: .leading, spacing: 8) {
//                Text("Activity level: \(activityDescription)")
//                    .font(.subheadline)
//                Slider(value: $profileActivityLevel, in: 1...5, step: 1)
//            }
//
//            VStack(alignment: .leading, spacing: 8) {
//                Text("Notes")
//                    .font(.subheadline)
//                TextField("Past injuries, dietary preferences…", text: $profileNotes, axis: .vertical)
//            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: themeManager.accent.color.opacity(0.3), radius: 12, y: 8)
    }
    

    
  
    private var habitsStepView: some View {
        VStack(spacing: 24) {
            curatedHabitsSection
            customHabitSection

            Button {
                completeOnboarding()
            } label: {
                Text("Start Tracking")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [
                                themeManager.complementary1AccentVariant,
                                themeManager.complementary2AccentVariant
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(themeManager.accent.color.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .purple.opacity(0.2), radius: 15, y: 8)

            }
            .disabled(!canCompleteOnboarding)


            Button("Back to Profile") {
                step = .profile
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.secondary)
            
        }
    }

    private var curatedHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Curated Habits")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(curated) { habit in
                    curatedHabitButton(for: habit)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    
    private var customHabitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or create your own")
                .font(.headline)
            TextField("Custom habit (optional)", text: $customHabitName)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
            Stepper("Daily target: \(customHabitTarget)", value: $customHabitTarget, in: 1...10000, step: 1)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    
    private func curatedHabitButton(for habit: CuratedHabit) -> some View {
        let isSelected = selectedHabits.contains(habit)
        return Button {
            toggleSelection(habit)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((isSelected ? habit.color.color : Color.secondary.opacity(0.15)))
                        .frame(width: 48, height: 48)
                    Image(systemName: habit.icon)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .font(.title3)
                        .symbolEffect(.pulse.byLayer, value: isSelected)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(isSelected ? "Added to your plan" : "Tap to include")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(habit.color.color)
                                .matchedGeometryEffect(id: habit.id, in: habitSelectionNamespace)
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? habit.color.color.opacity(0.15) : Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(isSelected ? 0.2 : 0.05),
                        radius: isSelected ? 12 : 4,
                        y: isSelected ? 8 : 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func toggleSelection(_ habit: CuratedHabit) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            if let index = selectedHabits.firstIndex(of: habit) {
                selectedHabits.remove(at: index)
            } else if selectedHabits.count < 3 {
                selectedHabits.append(habit)
            }
        }
    }



    private func completeOnboarding() {
        guard canCompleteOnboarding else { return }
        persistProfile()

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
                accentColorKey: AccentTheme.blue.rawValue,
                order: createdCount,
                dailyTarget: customHabitTarget
            )
            context.insert(model)
        }

        do {
            if context.hasChanges {
                try context.save()
            }
//            hasCompletedOnboarding = true
        } catch {
            showingSaveError = true
        }
    }
    
    private func persistProfile() {
        storedName = profileName.trimmingCharacters(in: .whitespaces)
        storedAge = profileAge
        storedHeightCm = profileHeight
        storedWeightKg = profileWeight
//        storedRestingHR = profileRestingHR
//        storedActivityLevel = profileActivityLevel
//        storedGoalRaw = profileGoal.rawValue
//        storedNotes = profileNotes
    }
    
    private var hasSelectedHabits: Bool {
        !selectedHabits.isEmpty || !customHabitName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isProfileComplete: Bool {
        !profileName.trimmingCharacters(in: .whitespaces).isEmpty &&
        profileAge >= 13
    }

    private var canCompleteOnboarding: Bool {
        hasSelectedHabits && isProfileComplete
    }
    
    
    private func updateAccentTheme(with sliderValue: Double) {
        let index = max(0, min(accentThemes.count - 1, Int(sliderValue.rounded())))
        let selectedTheme = accentThemes[index]
        storedAccentTheme = selectedTheme.rawValue
    }

    private func syncAccentSlider() {
        if let index = accentThemes.firstIndex(of: accentTheme) {
            accentSliderValue = Double(index)
        }
    }
    
}


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
enum OnboardingStep: String {
    case profile
    case habits
}
