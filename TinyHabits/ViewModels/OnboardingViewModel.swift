import Foundation
import SwiftUI
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var profileName: String = ""
    @Published var profileAge: Int = 30
    @Published var profileHeight: Int = 170
    @Published var profileWeight: Int = 70
    @Published var showingProfileValidation = false

    var isProfileComplete: Bool {
        !profileName.trimmingCharacters(in: .whitespaces).isEmpty && profileAge >= 13
    }
}
