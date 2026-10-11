import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// The Flown shelf: graduated habits (docs/DESIGN.md §6.5). Custom bird art replaces the SF Symbol with DES-3.
struct FlownSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var flown: [Habit]
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: FledgeTheme.Space.m)]

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
                        description: Text("Your first habit can fly from day \(GraduationRule.standard.minDays).")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: FledgeTheme.Space.m) {
                            ForEach(flown) { habit in
                                FlownTile(habit: habit, flewText: flewText(habit))
                                    .contextMenu {
                                        Button("Bring back to the nest", systemImage: "arrow.uturn.backward") { bringBack(habit) }
                                    }
                                    .accessibilityAction(named: "Bring back to the nest") { bringBack(habit) }
                            }
                        }
                        .padding(FledgeTheme.screenMargin)
                    }
                    .background(FledgeTheme.Palette.cloud)
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
            HealthSync.shared?.updateObservers()
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one first."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FlownTile: View {
    let habit: Habit
    let flewText: String

    var body: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
            Image(systemName: "bird.fill")
                .font(.system(size: 36))
                .foregroundStyle(FledgeTheme.habitColor(habit.colorKey))
            Text(habit.name)
                .font(.headline)
                .foregroundStyle(FledgeTheme.Palette.ink)
            Text(flewText)
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
        .padding(FledgeTheme.Space.l)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(FledgeTheme.Palette.card, in: .rect(cornerRadius: FledgeTheme.Radius.tile))
        .overlay {
            RoundedRectangle(cornerRadius: FledgeTheme.Radius.tile)
                .strokeBorder(FledgeTheme.Palette.gold.opacity(0.4), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
