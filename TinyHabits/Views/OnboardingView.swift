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
//    @State private var profileRestingHR: Int = 65
//    @State private var profileActivityLevel: Double = 3
//    @State private var profileGoal: ActivityGoal = .balance
//    @State private var profileNotes: String = ""
//    @State private var didSeedProfileState = false
    @State private var step: OnboardingStep = .profile
    @State private var showingProfileValidation = false
    
    private let curated: [CuratedHabit] = CuratedHabit.onboardingOptions
    
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
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
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
            
            heroImageView
                .frame(maxHeight: 180)
                .padding(.horizontal, 32)
                .offset(x: heroAnimate ? 40 : 60, y: heroAnimate ? -10 : 10)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("TinyHabits")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .opacity(heroAnimate ? 1 : 0.6)
                Text("Pick up to three tiny habits to focus on every day.")
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                HStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .scaleEffect(heroAnimate ? 1 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).repeatForever(autoreverses: true), value: heroAnimate)
                    Text("Small steps. Big change.")
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.headline)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .shadow(color: .purple.opacity(0.35), radius: 30, y: 20)
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
                .foregroundStyle(.white.opacity(0.45))
                .accessibilityLabel("Running illustration")
        }
    }

    @ViewBuilder
    private var stepContent: some View {
//        switch step {
//    case .profile:
           profileStepView
//        case .habits:
//            habitsStepView
//        }
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
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .purple.opacity(0.2), radius: 15, y: 8)
            }
        }
    }
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Your Profile")
                .font(.headline)

            TextField("Full name", text: $profileName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
            Stepper("Age: \(profileAge)", value: $profileAge, in: 13...100)

            VStack(alignment: .leading, spacing: 8) {
                Text("Physical Details")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Stepper("Height: \(profileHeight) cm", value: $profileHeight, in: 120...230)
                Stepper("Weight: \(profileWeight) kg", value: $profileWeight, in: 40...200)
//                Stepper("Resting HR: \(profileRestingHR) bpm", value: $profileRestingHR, in: 40...120)
            }

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
    }
    
    private var isProfileComplete: Bool {
        !profileName.trimmingCharacters(in: .whitespaces).isEmpty &&
        profileAge >= 13
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
