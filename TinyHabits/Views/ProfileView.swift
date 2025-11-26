import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var profileImagePickerItem: PhotosPickerItem?

    private var accent: Color { AccentTheme(rawValue: viewModel.accentRaw)?.color ?? .blue }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HeroHeader(
                        title: viewModel.name.isEmpty ? "Let’s personalize your journey" : "Keep going, \(viewModel.name)",
                        subtitle: viewModel.quote.isEmpty ? "Small steps, daily. Update your stats and stay motivated." : viewModel.quote,
                        accent: accent,
                        quote: nil,
                        imageName: AssetNames.profileHero
                    )

                    photoCard
                    ProfileStatsView(viewModel: viewModel)
                    HealthKitView()
//                    motivationCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.headline)
            HStack(spacing: 16) {
                let currentImage = viewModel.profileImage
                PhotosPicker(selection: $profileImagePickerItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        if let image = currentImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(accent.opacity(0.6))
                                .padding(12)
                        }
                        Circle()
                            .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
                            .padding(4)
                    }
                }
                .onChange(of: profileImagePickerItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                viewModel.updatePhoto(data: data)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .frame(width: 90, height: 90)
                .background(Color(.secondarySystemBackground), in: Circle())

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Full name", text: $viewModel.name)
                        .textContentType(.name)
                        .textFieldStyle(.roundedBorder)
//                    HStack {
//                        Text("Age: \(viewModel.age)")
//                        Slider(value: Binding(get: { Double(viewModel.age) }, set: { viewModel.age = Int($0.rounded()) }), in: 13...100, step: 1)
//                    }
                }
            }
            Text("Tap the avatar to update your photo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(DesignTokens.cardBackground())
    }

//    private var statsCard: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Body stats")
//                .font(.headline)
//            VStack(alignment: .leading, spacing: 10) {
//                HStack {
//                    Text("Height: \(viewModel.heightCm) cm")
//                    Slider(value: Binding(get: { Double(viewModel.heightCm) }, set: { viewModel.heightCm = Int($0.rounded()) }), in: 120...230, step: 1)
//                }
//                HStack {
//                    Text("Weight: \(viewModel.weightKg) kg")
//                    Slider(value: Binding(get: { Double(viewModel.weightKg) }, set: { viewModel.weightKg = Int($0.rounded()) }), in: 40...200, step: 1)
//                }
//            }
//        }
//        .padding()
//        .background(DesignTokens.cardBackground())
//    }

//    private var motivationCard: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            Text("Motivation")
//                .font(.headline)
//            Toggle("Daily quote on launch", isOn: $viewModel.showDailyQuotes)
//            Toggle("Celebration haptics", isOn: $viewModel.enableHaptics)
//            Text("Keep the vibes strong with small nudges and celebratory feedback.")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//        }
//        .padding()
//        .background(DesignTokens.cardBackground())
//    }
}
