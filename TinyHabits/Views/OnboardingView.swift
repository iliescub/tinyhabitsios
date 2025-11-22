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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
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
    @State private var sparklePulse = false
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
//                    stepIndicator
//                        .padding(.top, 8)

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
            withAnimation(.easeInOut(duration: 1.6).repeatForever()) {
                sparklePulse.toggle()
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
                .foregroundStyle(.primary.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(accentThemes.enumerated()), id: \.element.id) { index, theme in
                        let gradient = gradientForTheme(theme)
                        Button {
                            accentSliderValue = Double(index)
                            updateAccentTheme(with: Double(index))
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                                    )
                                    .shadow(color: gradient.first?.opacity(0.35) ?? .clear, radius: 12, y: 6)
                                    .frame(width: 110, height: 70)
                                    .overlay(alignment: .topTrailing) {
                                        Circle()
                                            .fill(theme.color)
                                            .frame(width: 22, height: 22)
                                            .shadow(color: theme.color.opacity(0.4), radius: 8, y: 4)
                                            .padding(8)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(index == Int(accentSliderValue.rounded()) ? theme.color.opacity(0.9) : .clear, lineWidth: 3)
                                    )
                                Text(theme.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

//            themePreview(gradient: gradientForTheme(accentTheme))
        }
        .padding()
        .background(glassBackground())
        .shadow(color: themeManager.accent.color.opacity(0.2), radius: 8, y: 4)
    }
    
    private func gradientForTheme(_ theme: AccentTheme) -> [Color] {
        let base = theme.color
        let complement = base.complementary
        return [
            complement.adjustingBrightness(by: -0.08),
            complement.adjustingBrightness(by: 0.12)
        ]
    }

    private func themePreview(gradient: [Color]) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Circle().fill(themeManager.accent.color.opacity(0.3)).frame(width: 12, height: 12)
                        Circle().fill(themeManager.accent.color.opacity(0.5)).frame(width: 12, height: 12)
                        Circle().fill(themeManager.accent.color.opacity(0.8)).frame(width: 12, height: 12)
                    }
                    Text("Live preview")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.9))
                    Text("See how buttons & cards will glow with this accent.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .shadow(color: gradient.first?.opacity(0.25) ?? .clear, radius: 12, y: 8)
    }
    
    private var stepIndicator: some View {
        HStack(spacing: 10) {
            stepPill(isActive: step == .profile, label: "Profile")
            stepPill(isActive: step == .habits, label: "Habits")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepPill(isActive: Bool, label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? themeManager.accent.color : .secondary.opacity(0.2))
                .frame(width: 10, height: 10)
                .shadow(color: isActive ? themeManager.accent.color.opacity(0.4) : .clear, radius: 6, y: 2)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(isActive ? themeManager.accent.color.opacity(0.6) : Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: isActive ? themeManager.accent.color.opacity(0.25) : .clear, radius: 10, y: 6)
        )
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
                .overlay(
                    Circle()
                        .fill(.white.opacity(0.15))
                        .scaleEffect(heroAnimate ? 1.05 : 0.8)
                        .offset(x: heroAnimate ? 40 : -20, y: heroAnimate ? -20 : -60)
                        .blur(radius: 30)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: heroAnimate)
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.25), lineWidth: 3)
                        .scaleEffect(heroAnimate ? 0.42 : 0.25)
                        .offset(x: heroAnimate ? 100 : 30, y: heroAnimate ? -60 : -10)
                        .shadow(color: .white.opacity(0.35), radius: 12)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: heroAnimate)
                )
            

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
                    .offset(y: heroAnimate ? -8 : 10)
                    .scaleEffect(heroAnimate ? 1.02 : 0.98)
                Spacer(minLength: 0)
                
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(themeManager.accent.color.opacity(0.8))
                        .scaleEffect(sparklePulse ? 1.08 : 0.92)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: sparklePulse)
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
        .shadow(color: themeManager.accent.color.opacity(0.4), radius: 18, y: 10)
    }
    
    @ViewBuilder
    private var heroImageView: some View {
        GeometryReader { proxy in
            let parallax = proxy.frame(in: .global).minY / 40
            Group {
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
            .offset(y: parallax)
            .animation(.easeOut(duration: 0.6), value: parallax)
        }
        .frame(height: 140)
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
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                themeManager.complementary1AccentVariant,
                                themeManager.complementary2AccentVariant
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .opacity(0.95)
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule(style: .continuous))
                    .shadow(color: themeManager.accent.color.opacity(0.35), radius: 18, y: 10)
                    .overlay(
                        Capsule()
                            .stroke(themeManager.accent.color.opacity(0.5), lineWidth: 1.4)
                    )
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
//                Text("Physical Details")
//                    .font(.subheadline)
                
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
        .background(glassBackground())
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
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
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
                    .foregroundStyle(.white)
                    .clipShape(Capsule(style: .continuous))
                    .shadow(color: themeManager.accent.color.opacity(0.35), radius: 18, y: 10)
                    .overlay(
                        Capsule()
                            .stroke(themeManager.accent.color.opacity(0.5), lineWidth: 1.4)
                    )
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
                if !customHabitName.trimmingCharacters(in: .whitespaces).isEmpty {
                    customHabitPreview
                }
            }
        }
        .padding()
        .background(glassBackground())
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
        .background(glassBackground())
    }

    private var customHabitPreview: some View {
        let trimmed = customHabitName.trimmingCharacters(in: .whitespaces)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(themeManager.accent.color)
                    .font(.title3)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(trimmed)
                    .font(.headline)
                Text("Daily target: \(customHabitTarget)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(themeManager.accent.color)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        )
    }
    
    private func glassBackground(cornerRadius: CGFloat = 24) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 10, y: 8)
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
            hasCompletedOnboarding = true
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
