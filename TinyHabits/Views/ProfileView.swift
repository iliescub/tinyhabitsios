import SwiftUI
import PhotosUI

struct ProfileView: View {
    @AppStorage("profile_name") private var name: String = ""
    @AppStorage("profile_age") private var age: Int = 30

    @AppStorage("profile_heightCm") private var heightCm: Int = 170
    @AppStorage("profile_weightKg") private var weightKg: Int = 70
//    @AppStorage("profile_activityLevel") private var activityLevel: Double = 3
//    @AppStorage("profile_goalRaw") private var goalRaw: String = ActivityGoal.balance.rawValue
//    @AppStorage("profile_notes") private var notes: String = ""
    @State private var profileImage: UIImage? //= ProfileImageStore.shared.load()
    @State private var isShowingPhotoPicker = false

//    private var selectedGoal: ActivityGoal {
//        ActivityGoal(rawValue: goalRaw) ?? .balance
//    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                physicalSection
//                goalSection
//                notesSection
            }
            .navigationTitle("Profile")
//            .sheet(isPresented: $isShowingPhotoPicker) {
//                ProfileImagePicker { image in
//                    if let image {
//                        profileImage = image
//                        ProfileImageStore.shared.save(image: image)
//                    }
//                }
//            }
        }
    }

    private var accountSection: some View {
        Section("Profile") {
            HStack {
                VStack {
                    if let profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Image("ProfilePlaceholder")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    }
                    Button("Change photo") {
                        isShowingPhotoPicker = true
                    }
                    .font(.caption)
                }
                .frame(width: 120)

                VStack(alignment: .leading) {
                    TextField("Full name", text: $name)
                        .textContentType(.name)
                    VStack(alignment: .leading) {
                        Text("Age: \(age)")
                        Slider(
                            value: Binding(
                                get: { Double(age) },
                                set: { age = Int($0.rounded()) }
                            ),
                            in: 13...100,
                            step: 1
                        )
                    }
                }
            }
        }
    }

    private var physicalSection: some View {
        Section("Physical Details") {
            VStack(alignment: .leading) {
                Text("Height: \(heightCm) cm")
                Slider(
                    value: Binding(
                        get: { Double(heightCm) },
                        set: { heightCm = Int($0.rounded()) }
                    ),
                    in: 120...230,
                    step: 1
                )
            }
            VStack(alignment: .leading) {
                Text("Weight: \(weightKg) kg")
                Slider(
                    value: Binding(
                        get: { Double(weightKg) },
                        set: { weightKg = Int($0.rounded()) }
                    ),
                    in: 40...200,
                    step: 1
                )
            }

//            VStack(alignment: .leading, spacing: 8) {
//                Text("Activity level")
//                Slider(value: $activityLevel, in: 1...5, step: 1)
//                Text(activityDescription)
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }
        }
    }

//    private var goalSection: some View {
//        Section("Focus") {
//            Picker("Primary goal", selection: Binding(
//                get: { selectedGoal },
//                set: { goalRaw = $0.rawValue }
//            )) {
//                ForEach(ActivityGoal.allCases) { goal in
//                    Text(goal.title).tag(goal)
//                }
//            }
//            Text(selectedGoal.description)
//                .font(.caption)
//                .foregroundStyle(.secondary)
//        }
//    }

//    private var notesSection: some View {
//        Section("Notes") {
//            TextField("Past injuries, dietary preferences…", text: $notes, axis: .vertical)
//            Text("Saved locally, never uploaded.")
//                .font(.caption2)
//                .foregroundStyle(.secondary)
//        }
//    }
//
//    private var activityDescription: String {
//        switch Int(activityLevel) {
//        case 1: return "Mostly sedentary"
//        case 2: return "Lightly active"
//        case 3: return "Moderately active"
//        case 4: return "Very active"
//        default: return "Athlete mode"
//        }
//    }
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

