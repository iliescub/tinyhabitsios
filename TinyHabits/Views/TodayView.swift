import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// Today — "the Nest": the only screen. Everything else is a sheet (docs/DESIGN.md §5, §6.1).
struct TodayView: View {
    let day: DayKey

    @Environment(\.modelContext) private var context
    @Query private var activeHabits: [Habit]
    @Query private var todayLogs: [DayLog]
    @State private var sheet: TodaySheet?
    @State private var habitToGraduate: Habit?
    @State private var errorMessage: String?

    init(day: DayKey) {
        self.day = day
        let active = HabitState.active.rawValue
        _activeHabits = Query(filter: #Predicate<Habit> { $0.stateRaw == active })
        let key = day.rawValue
        _todayLogs = Query(filter: #Predicate<DayLog> { $0.dayKey == key })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
                    header
                    ForEach(0..<SlotPolicy.maxActive, id: \.self) { slot in
                        if let habit = habit(inSlot: slot) {
                            card(for: habit)
                        } else {
                            EmptySlotCard { sheet = .add }
                        }
                    }
                }
                .padding(.horizontal, FledgeTheme.screenMargin)
                .padding(.bottom, FledgeTheme.Space.xxl)
            }
            .background(SkyBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Flown", systemImage: "bird") { sheet = .flown }
                    Button("Settings", systemImage: "gearshape") { sheet = .settings }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if hasFreeSlot {
                    AddHabitButton { sheet = .add }
                        .padding(.bottom, FledgeTheme.Space.s)
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .add: AddHabitSheet()
                case .flown: FlownSheet()
                case .settings: SettingsSheet()
                }
            }
            .confirmationDialog(
                habitToGraduate.map { "\($0.name) is ready to fly." } ?? "",
                isPresented: Binding(get: { habitToGraduate != nil }, set: { if !$0 { habitToGraduate = nil } }),
                titleVisibility: .visible
            ) {
                Button("Let it fly") {
                    if let habit = habitToGraduate { perform { try context.graduate(habitID: habit.id) } }
                }
                Button("Keep it in the nest for now", role: .cancel) {}
            } message: {
                Text("Flown habits keep tracking quietly. Its slot opens for a new habit.")
            }
            .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
            Text(day.date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
                .foregroundStyle(FledgeTheme.Palette.ink)
            Text(TodaySummary.text(for: sortedHabits.map(model(for:))))
                .font(.subheadline)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
        .padding(.top, FledgeTheme.Space.s)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Cards

    private func card(for habit: Habit) -> some View {
        let model = model(for: habit)
        let isDone = model.progress.status == .done
        return HabitCardView(
            model: model,
            onToggleDone: { perform { try context.setDone(!isDone, habitID: habit.id, on: day, by: .manual) } },
            onSkip: { perform { try context.skip(habitID: habit.id, on: day) } },
            onUndoSkip: { perform { try context.setDone(false, habitID: habit.id, on: day, by: .manual) } },
            onReadyToFly: { habitToGraduate = habit },
            onPause: { perform { try context.pause(habitID: habit.id) } },
            onDelete: { perform { try context.deleteHabit(habitID: habit.id) } }
        )
    }

    private func model(for habit: Habit) -> HabitCardModel {
        let log = todayLogs.first { $0.habit?.id == habit.id }
        return HabitCardModel(
            name: habit.name,
            symbol: habit.symbol,
            colorKey: habit.colorKey,
            source: habit.source,
            target: habit.target,
            unit: habit.unit,
            cadence: habit.cadence,
            startedOn: DayKey(habit.startedAt),
            today: day,
            todayValue: log?.value ?? 0,
            todayStatus: log?.status ?? .pending,
            todayCompletedBy: log?.completedBy,
            history: habit.logs?.compactMap(\.snapshot) ?? []
        )
    }

    private var sortedHabits: [Habit] {
        activeHabits.sorted { ($0.slot ?? .max) < ($1.slot ?? .max) }
    }

    private func habit(inSlot slot: Int) -> Habit? {
        activeHabits.first { $0.slot == slot }
    }

    private var hasFreeSlot: Bool {
        activeHabits.count < SlotPolicy.maxActive
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one to add another."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum TodaySheet: String, Identifiable {
    case add, flown, settings
    var id: String { rawValue }
}

/// Floating primary action; Liquid Glass on iOS 26, prominent bordered before.
struct AddHabitButton: View {
    let action: () -> Void

    var body: some View {
        let button = Button(action: action) {
            Label("Add habit", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, FledgeTheme.Space.s)
                .padding(.vertical, FledgeTheme.Space.xs)
        }
        .buttonBorderShape(.capsule)
        .tint(FledgeTheme.Palette.skyText)

        if #available(iOS 26, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }
}
