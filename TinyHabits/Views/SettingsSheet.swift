import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// Settings (docs/DESIGN.md §6.8). Day end, paused habits and About; the rest arrives with SET-1.
struct SettingsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var paused: [Habit]
    @State private var errorMessage: String?
    @AppStorage(FledgeSettings.dayEndHourKey, store: FledgeSettings.defaults) private var dayEndHour = FledgeSettings.defaultDayEndHour

    init() {
        let pausedState = HabitState.paused.rawValue
        _paused = Query(filter: #Predicate<Habit> { $0.stateRaw == pausedState }, sort: \Habit.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Day ends at", selection: $dayEndHour) {
                        ForEach(Array(FledgeSettings.dayEndHourRange), id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                } footer: {
                    Text("Anything you do before this time counts for the previous day — handy for late nights.")
                }

                Section {
                    if paused.isEmpty {
                        Text("No paused habits")
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                    ForEach(paused) { habit in
                        HStack {
                            Label(habit.name, systemImage: habit.symbol)
                            Spacer()
                            Button("Resume") { resume(habit) }
                                .buttonStyle(.borderless)
                        }
                    }
                } header: {
                    Text("Paused habits")
                } footer: {
                    Text("Pausing frees a slot and keeps the habit's history.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Label("No account. Your Health data stays on your iPhone.", systemImage: "lock.fill")
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Couldn't resume", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return hour == 0 ? "Midnight" : date.formatted(date: .omitted, time: .shortened)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func resume(_ habit: Habit) {
        do {
            try context.resume(habitID: habit.id)
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one first."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
