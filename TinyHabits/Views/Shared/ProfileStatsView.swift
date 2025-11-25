import SwiftUI

struct ProfileStatsView: View {
    @Binding var age: Int
    @Binding var heightCm: Int
    @Binding var weightKg: Int
    @AppStorage("accentTheme") private var storedAccentTheme: String = AccentTheme.blue.rawValue

    init(age: Binding<Int>, heightCm: Binding<Int>, weightKg: Binding<Int>) {
        self._age = age
        self._heightCm = heightCm
        self._weightKg = weightKg
    }

    init(viewModel: ProfileViewModel) {
        self._age = Binding(get: { viewModel.age }, set: { viewModel.age = $0 })
        self._heightCm = Binding(get: { viewModel.heightCm }, set: { viewModel.heightCm = $0 })
        self._weightKg = Binding(get: { viewModel.weightKg }, set: { viewModel.weightKg = $0 })
    }

    private var accent: Color {
        AccentTheme(rawValue: storedAccentTheme)?.color ?? .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Body stats")
                .font(.headline)
                .foregroundStyle(accent.opacity(0.8))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
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
                HStack {
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
                HStack {
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
            }
        }
        .padding()
        .background(DesignTokens.cardBackground())
    }
}
