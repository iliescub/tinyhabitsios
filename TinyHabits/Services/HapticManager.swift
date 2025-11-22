import UIKit

enum HapticType {
    case success
    case soft
    case light
    case warning
    case heavy
    case celebrate
}

final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func play(_ type: HapticType) {
        // Ensure execution on the main thread to avoid silent failures.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.play(type)
            }
            return
        }
        switch type {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .soft:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .celebrate:
            // Layered haptics for a celebratory feel.
            let success = UINotificationFeedbackGenerator()
            success.notificationOccurred(.success)
            let soft = UIImpactFeedbackGenerator(style: .soft)
            soft.impactOccurred(intensity: 0.8)
        }
    }
}
