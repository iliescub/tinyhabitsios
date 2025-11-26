import Foundation
import SwiftUI
import SwiftData
import UIKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("profile_name") private var storedName: String = ""
    @AppStorage("profile_age") private var storedAge: Int = 30
    @AppStorage("profile_heightCm") private var storedHeightCm: Int = 170
    @AppStorage("profile_weightKg") private var storedWeightKg: Int = 70
    @AppStorage("accentTheme") private var storedAccentTheme: String = AccentTheme.blue.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @StateObject private var viewModel = OnboardingViewModel()
    @StateObject private var habitsViewModel = SettingsViewModel()
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.order, order: .forward)
    private var habits: [Habit]

    @State private var heroAnimate = false
    @State private var sparklePulse = false
    @State private var currentStep: OnboardingStep = .profile

    private var accentThemes: [AccentTheme] { AccentTheme.allCases }
    private var accentTheme: AccentTheme {
        AccentTheme(rawValue: storedAccentTheme) ?? .blue
    }
    private var accentColor: Color { accentTheme.color }
    private var complementaryAccent: Color { accentColor.complementary }
    private var complementaryAccentVariant1: Color { complementaryAccent.adjustingBrightness(by: -0.1) }
    private var complementaryAccentVariant2: Color { complementaryAccent.adjustingBrightness(by: 0.1) }

    private enum OnboardingStep {
        case profile
        case habits
    }

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
                        accentColor.opacity(0.15),
                        complementaryAccent.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .onAppear {
            habitsViewModel.setContext(context)
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) {
                heroAnimate = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever()) {
                sparklePulse.toggle()
            }
        }
        .alert("Complete Your Profile", isPresented: $viewModel.showingProfileValidation, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("Add your name and age before picking habits.")
        })
    }

    private var stepContent: some View {
        VStack(spacing: 20) {
    

            VStack(spacing: 24) {
//                stepIndicator
                if currentStep == .profile {
                    ThemeView()
                    profileStep
                } else {
                    HabitsView()
                        .environmentObject(habitsViewModel)
                    habitsStep
                }
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 12) {
            stepCircle(isActive: currentStep == .profile, title: "1")
            stepCircle(isActive: currentStep == .habits, title: "2")
            Text(currentStep == .profile ? "Profile" : "Habits")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func stepCircle(isActive: Bool, title: String) -> some View {
        Circle()
            .strokeBorder(isActive ? accentColor : Color.secondary.opacity(0.4), lineWidth: 2)
            .background(Circle().fill(isActive ? accentColor.opacity(0.2) : Color.clear))
            .frame(width: 30, height: 30)
            .overlay(Text(title).font(.caption))
    }

    private var profileStep: some View {
        VStack(spacing: 16) {
            profileSection
            Button {
                currentStep = .habits
            } label: {
                Text("Next: Choose habits")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule(style: .continuous))
            }
            .disabled(!viewModel.isProfileComplete)
            .opacity(viewModel.isProfileComplete ? 1 : 0.5)
        }
    }
    private var habitsStep: some View {
        VStack(spacing: 12) {
            Button(action: {
                currentStep = .profile
            }) {
                Label("Back to profile", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(accentColor)
//            .tint(accentColor)

            Button {
                completeOnboarding()
            } label: {
                Text("Start Tracking")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor
//                        LinearGradient(
//                            colors: [
//                                complementaryAccentVariant1,
//                                complementaryAccentVariant2
//                            ],
//                            startPoint: .leading,
//                            endPoint: .trailing
//                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule(style: .continuous))
//                    .shadow(color: accentColor.opacity(0.35), radius: 18, y: 10)
//                    .overlay(
//                        Capsule()
//                            .stroke(accentColor.opacity(0.5), lineWidth: 1.4)
//                    )
            }
            .disabled(!canCompleteOnboarding)
        }
    }

    private var heroSection: some View {
        HeroHeader(
            title: "TinyHabits",
            subtitle: "Pick up to 3 habits to focus on daily.",
            accent: accentColor,
            quote: "Small steps. Big changes.",
            imageName: AssetNames.onboardingHero
        )
        .overlay(
            Circle()
                .strokeBorder(.white.opacity(0.25), lineWidth: 3)
                .scaleEffect(heroAnimate ? 0.42 : 0.25)
                .offset(x: heroAnimate ? 100 : 30, y: heroAnimate ? -60 : -10)
                .shadow(color: .white.opacity(0.35), radius: 12)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: heroAnimate)
        )
        .frame(height: 220)
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Your Profile")
                .font(.headline)
                .foregroundStyle(accentColor.opacity(0.8))

            TextField("Add your name before moving to habits", text: $viewModel.profileName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .foregroundStyle(accentColor.opacity(0.8))
            ProfileStatsView(
                age: $viewModel.profileAge,
                heightCm: $viewModel.profileHeight,
                weightKg: $viewModel.profileWeight
            )

        }
        .padding()
//        .background(glassBackground())
        .shadow(color: accentColor.opacity(0.3), radius: 12, y: 8)
    }


    private func completeOnboarding() {
        guard canCompleteOnboarding else {
            viewModel.showingProfileValidation = true
            return
        }
        persistProfile()
        hasCompletedOnboarding = true
        if context.hasChanges {
            try? context.save()
        }
    }

    private func persistProfile() {
        storedName = viewModel.profileName.trimmingCharacters(in: .whitespaces)
        storedAge = viewModel.profileAge
        storedHeightCm = viewModel.profileHeight
        storedWeightKg = viewModel.profileWeight
    }

    private var canCompleteOnboarding: Bool {
        viewModel.isProfileComplete && habitsViewModel.activeHabits(using: habits).count > 0 && habitsViewModel.activeHabits(using: habits).count <= 3
    }

}
