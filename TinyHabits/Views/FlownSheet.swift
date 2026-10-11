import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// The Flown shelf: graduated habits (docs/DESIGN.md §6.5). Bird art and grid layout come with DES-3.
struct FlownSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var flown: [Habit]
    @State private var errorMessage: String?

    init() {
        let graduated = HabitState.graduated.rawValue
        _flown = Query(filter: #Predicate<Habit> { $0.stateRaw == graduated }, sort: \Habit.name)
    }

    var body: some View {
        NavigationStack {
            Group {
                if flown.isEmpty {
                    ContentUnavailableView(
                        "Nothing has flown yet",
                        systemImage: "bird",
                        description: Text("Your first habit can fly from day 30.")
                    )
                } else {
                    List(flown) { habit in
                        HStack(spacing: FledgeTheme.Space.m) {
                            Image(systemName: "bird.fill")
                                .font(.title2)
                                .foregroundStyle(FledgeTheme.habitColor(habit.colorKey))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name).font(.headline)
                                Text(flewText(habit))
                                    .font(.subheadline)
                                    .foregroundStyle(FledgeTheme.Palette.ink2)
                            }
                        }
                        .swipeActions {
                            Button("Bring back", systemImage: "arrow.uturn.backward") { bringBack(habit) }
                                .tint(FledgeTheme.Palette.skyText)
                        }
                    }
                }
            }
            .navigationTitle("Flown")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Couldn't bring it back", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func flewText(_ habit: Habit) -> String {
        guard let graduatedAt = habit.graduatedAt else { return "Flown" }
        let days = DayKey(habit.startedAt).days(to: DayKey(graduatedAt)) + 1
        return "Flew \(graduatedAt.formatted(.dateTime.month(.abbreviated).day())) · \(days) days"
    }

    private func bringBack(_ habit: Habit) {
        do {
            try context.resume(habitID: habit.id)
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one first."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
