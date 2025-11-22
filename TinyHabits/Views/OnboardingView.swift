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

    @Namespace private var habitSelectionNamespace
    @State private var heroAnimate = false
    @State private var sparklePulse = false

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
            withAnimation(.easeInOut(duration: 1.6).repeatForever()) {
                sparklePulse.toggle()
            }
        }
        .alert("Something Went Wrong", isPresented: $viewModel.showingSaveError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("We couldn't save your habits. Please try again after restarting the app.")
        })
        .alert("Complete Your Profile", isPresented: $viewModel.showingProfileValidation, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text("Add your name and age before picking habits.")
        })
        .onChange(of: storedAccentTheme) { _, _ in
            syncAccentSlider()
        }
    }

    private var stepContent: some View {
        VStack(spacing: 20) {
            themeSelector
            profileSection

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
                .disabled(!viewModel.canCompleteOnboarding(accentThemes: accentThemes, storedAccentTheme: storedAccentTheme))
            }
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
                        ThemeChip(theme: theme, isSelected: Int(viewModel.accentSliderValue.rounded()) == index) {
                            viewModel.accentSliderValue = Double(index)
                            updateAccentTheme(with: Double(index))
                        }
                    }
                }
            }

            themePreview(gradient: gradientForTheme(accentTheme))
        }
        .padding()
        .background(glassBackground())
        .shadow(color: themeManager.accent.color.opacity(0.2), radius: 8, y: 4)
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

    private var heroSection: some View {
        HeroHeader(
            title: "TinyHabits",
            subtitle: "Pick up to 3 habits to focus on daily.",
            accent: themeManager.accent.color,
            quote: "Small steps. Big change.",
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
                .foregroundStyle(themeManager.accent.color.opacity(0.8))

            TextField("Full name", text: $viewModel.profileName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .foregroundStyle(themeManager.accent.color.opacity(0.8))
            Stepper("Age: \(viewModel.profileAge)", value: $viewModel.profileAge, in: 13...100)
                .foregroundStyle(themeManager.accent.color.opacity(0.8))

            VStack(alignment: .leading, spacing: 8) {
                Text("Physical Details")
                    .font(.subheadline)

                Stepper("Height: \(viewModel.profileHeight) cm", value: $viewModel.profileHeight, in: 120...230)
                Stepper("Weight: \(viewModel.profileWeight) kg", value: $viewModel.profileWeight, in: 40...200)
            }
            .foregroundStyle(themeManager.accent.color.opacity(0.8))
        }
        .padding()
        .background(glassBackground())
        .shadow(color: themeManager.accent.color.opacity(0.3), radius: 12, y: 8)
    }

    private var curatedHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Curated Habits")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(curated) { habit in
                    curatedHabitButton(for: habit)
                }
                if !viewModel.customHabitName.trimmingCharacters(in: .whitespaces).isEmpty {
                    customHabitButton
                }
            }
        }
        .padding()
        .background(glassBackground())
    }

    private var customHabitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom habit")
                .font(.headline)
            TextField("Custom habit (optional)", text: $viewModel.customHabitName)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
            Stepper("Daily target: \(viewModel.customHabitTarget)", value: $viewModel.customHabitTarget, in: 1...10000, step: 1)
        }
        .padding()
        .background(glassBackground())
    }

    private func curatedHabitButton(for habit: CuratedHabit) -> some View {
        let isSelected = viewModel.selectedHabits.contains(habit)
        return Button {
            viewModel.toggleSelection(habit)
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

    private var customHabitButton: some View {
        let trimmed = viewModel.customHabitName.trimmingCharacters(in: .whitespaces)
        let isSelected = viewModel.selectedHabits.contains(where: { $0.name.lowercased() == trimmed.lowercased() })
        return Button {
            let custom = CuratedHabit(name: trimmed, icon: "sparkles", color: accentTheme, defaultTarget: viewModel.customHabitTarget)
            viewModel.toggleSelection(custom)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? accentTheme.color : Color.secondary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .foregroundStyle(isSelected ? .white : themeManager.accent.color)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(trimmed)
                        .font(.headline)
                    Text("Daily target: \(viewModel.customHabitTarget)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(accentTheme.color))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? accentTheme.color.opacity(0.15) : Color(.systemBackground))
                    .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.08), radius: isSelected ? 10 : 6, y: isSelected ? 6 : 4)
            )
        }
        .buttonStyle(.plain)
    }

    private func completeOnboarding() {
        guard viewModel.canCompleteOnboarding(accentThemes: accentThemes, storedAccentTheme: storedAccentTheme) else {
            viewModel.showingProfileValidation = true
            return
        }
        viewModel.save(accentThemes: accentThemes, storedAccentTheme: storedAccentTheme)
        persistProfile()
        hasCompletedOnboarding = true
    }

    private func persistProfile() {
        storedName = viewModel.profileName.trimmingCharacters(in: .whitespaces)
        storedAge = viewModel.profileAge
        storedHeightCm = viewModel.profileHeight
        storedWeightKg = viewModel.profileWeight
    }

    private func updateAccentTheme(with sliderValue: Double) {
        let index = max(0, min(accentThemes.count - 1, Int(sliderValue.rounded())))
        let selectedTheme = accentThemes[index]
        storedAccentTheme = selectedTheme.rawValue
    }

    private func syncAccentSlider() {
        if let index = viewModel.accentIndex(accentThemes: accentThemes, stored: storedAccentTheme) {
            viewModel.accentSliderValue = Double(index)
        }
    }

    private func gradientForTheme(_ theme: AccentTheme) -> [Color] {
        let base = theme.color
        let complement = base.complementary
        return [
            complement.adjustingBrightness(by: -0.08),
            complement.adjustingBrightness(by: 0.12)
        ]
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
}
