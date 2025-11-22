import SwiftUI
import PhotosUI

struct ProfileView: View {
    @AppStorage("profile_name") private var name: String = ""
    @AppStorage("profile_age") private var age: Int = 30
    @AppStorage("profile_heightCm") private var heightCm: Int = 170
    @AppStorage("profile_weightKg") private var weightKg: Int = 70
    @AppStorage("motivation_dailyQuotes") private var showDailyQuotes: Bool = true
    @AppStorage("motivation_haptics") private var enableHaptics: Bool = true
    @AppStorage("accentTheme") private var accentRaw: String = AccentTheme.blue.rawValue
    @AppStorage("profile_imageData") private var storedImageData: Data = Data()

    @State private var profileImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var accent: Color { AccentTheme(rawValue: accentRaw)?.color ?? .blue }
    private var accentGradient: [Color] {
        [
            accent.adjustingBrightness(by: -0.06),
            accent.adjustingBrightness(by: 0.12)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    photoCard
                    statsCard
//                    motivationCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profile")
        }
        .onAppear(perform: loadImageFromStore)
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let compressed = compress(image: image)
                    profileImage = compressed
                    if let compressedData = compressed.jpegData(compressionQuality: 0.8) {
                        storedImageData = compressedData
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: accent.opacity(0.25), radius: 18, y: 10)

            VStack(alignment: .leading, spacing: 10) {
                Text(name.isEmpty ? "Let’s personalize your journey" : "Keep going, \(name)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Small steps, daily. Update your stats and stay motivated.")
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.subheadline)
            }
            .padding(20)
        }
        .frame(height: 140)
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline)
            HStack(spacing: 16) {
                ZStack {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(accent.opacity(0.6))
                            .padding(12)
                    }
                }
                .frame(width: 90, height: 90)
                .background(Color(.secondarySystemBackground), in: Circle())

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Full name", text: $name)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("Age: \(age)")
                        Slider(value: Binding(get: { Double(age) }, set: { age = Int($0.rounded()) }), in: 13...100, step: 1)
                    }
                }
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Update photo", systemImage: "photo")
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
        }
        .padding()
        .background(cardBackground())
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Body stats")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Height: \(heightCm) cm")
                    Slider(value: Binding(get: { Double(heightCm) }, set: { heightCm = Int($0.rounded()) }), in: 120...230, step: 1)
                }
                HStack {
                    Text("Weight: \(weightKg) kg")
                    Slider(value: Binding(get: { Double(weightKg) }, set: { weightKg = Int($0.rounded()) }), in: 40...200, step: 1)
                }
            }
        }
        .padding()
        .background(cardBackground())
    }

    private var motivationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Motivation")
                .font(.headline)
            Toggle("Daily quote on launch", isOn: $showDailyQuotes)
            Toggle("Celebration haptics", isOn: $enableHaptics)
            Text("Keep the vibes strong with small nudges and celebratory feedback.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(cardBackground())
    }

    // MARK: - Helpers

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

    private func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.06), radius: 10, y: 6)
    }
}

//enum ActivityGoal: String, CaseIterable, Identifiable {
//    case balance
//    case energy
//    case strength
//    case recovery
//
//    var id: String { rawValue }
//
//    var title: String {
//        switch self {
//        case .balance: return "Balanced health"
//        case .energy: return "Boost energy"
//        case .strength: return "Build strength"
//        case .recovery: return "Recovery & stress"
//        }
//    }
//
//    var description: String {
//        switch self {
//        case .balance:
//            return "Keep things steady with a mix of movement, nutrition, and rest."
//        case .energy:
//            return "Focus on routines that support stamina and daily focus."
//        case .strength:
//            return "Prioritize habits that improve muscular strength and durability."
//        case .recovery:
//            return "Dial in restorative rituals—sleep, mobility, and mindfulness."
//        }
//    }
