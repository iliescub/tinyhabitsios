import Foundation
import Combine
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @AppStorage("profile_name") var name: String = ""
    @AppStorage("profile_age") var age: Int = 30
    @AppStorage("profile_heightCm") var heightCm: Int = 170
    @AppStorage("profile_weightKg") var weightKg: Int = 70
    @AppStorage("motivation_dailyQuotes") var showDailyQuotes: Bool = true
    @AppStorage("motivation_haptics") var enableHaptics: Bool = true
    @AppStorage("accentTheme") var accentRaw: String = AccentTheme.blue.rawValue
    @AppStorage("profile_imageData") private var storedImageData: Data = Data()

    @Published var profileImage: UIImage?
    @Published var quote: String = ""

    init() {
        loadImageFromStore()
        loadQuote()
    }

    func updatePhoto(data: Data?) {
        guard let data, let image = UIImage(data: data) else { return }
        let compressed = compress(image: image)
        profileImage = compressed
        if let compressedData = compressed.jpegData(compressionQuality: 0.8) {
            storedImageData = compressedData
        }
    }

    private func loadImageFromStore() {
        if !storedImageData.isEmpty, let image = UIImage(data: storedImageData) {
            profileImage = image
        }
    }

    private func compress(image: UIImage, maxDimension: CGFloat = 400) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func loadQuote() {
        quote = MotivationProvider.dailyQuote()
    }
}
