import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// Today — "the Nest": the only screen. Everything else is a sheet or a cover (docs/DESIGN.md §5, §6.1).
struct TodayView: View {
    let day: DayKey

    @Environment(\.modelContext) private var context
    @Query private var activeHabits: [Habit]
    @Query private var todayLogs: [DayLog]
    @State private var sheet: TodaySheet?
    @State private var detailHabit: Habit?
    @State private var graduatingHabit: Habit?
    @State private var amountHabit: Habit?
    @State private var amountText = ""
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
                    PrimaryActionButton(title: "Add habit", systemImage: "plus") { sheet = .add }
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
            .sheet(item: $detailHabit) { habit in
                HabitDetailSheet(habit: habit, day: day) {
                    Task {
                        // Let the detail sheet finish dismissing before presenting the cover.
                        try? await Task.sleep(for: .milliseconds(450))
                        graduatingHabit = habit
                    }
                }
            }
            .fullScreenCover(item: $graduatingHabit) { habit in
                GraduationView(habit: habit, day: day) {
                    graduatingHabit = nil
                    perform(structural: true) { try context.graduate(habitID: habit.id) }
                } onKeep: {
                    graduatingHabit = nil
                }
            }
            #if DEBUG
            .task { openDemoScreen() }
            #endif
            .alert(amountTitle, isPresented: Binding(get: { amountHabit != nil }, set: { if !$0 { amountHabit = nil } })) {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                Button("Add") { logAmount() }
                Button("Cancel", role: .cancel) {}
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
            actions: HabitCardActions(
                open: { detailHabit = habit },
                toggleDone: { perform { try context.setDone(!isDone, habitID: habit.id, on: day, by: .manual) } },
                addIncrement: {
                    perform { try context.addAmount(DayEvaluator.increment(for: habit.target), habitID: habit.id, on: day) }
                },
                logAmount: {
                    amountText = ""
                    amountHabit = habit
                },
                skip: { perform { try context.skip(habitID: habit.id, on: day) } },
                undoSkip: { perform { try context.setDone(false, habitID: habit.id, on: day, by: .manual) } },
                readyToFly: { graduatingHabit = habit },
                pause: { perform(structural: true) { try context.pause(habitID: habit.id) } },
                delete: { perform(structural: true) { try context.deleteHabit(habitID: habit.id) } }
            ),
            showsNoDataHint: showsNoDataHint(for: habit, model: model)
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
            startedOn: DayKey(habit.startedAt, dayEndHour: FledgeSettings.dayEndHour),
            today: day,
            todayValue: log?.value ?? 0,
            todayStatus: log?.status ?? .pending,
            todayCompletedBy: log?.completedBy,
            history: habit.logs?.compactMap(\.snapshot) ?? []
        )
    }

    private func showsNoDataHint(for habit: Habit, model: HabitCardModel) -> Bool {
        guard habit.source.isAuto else { return false }
        let logs = habit.logs ?? []
        let previous = [day.adding(days: -1), day.adding(days: -2)].map { past in
            logs.first { $0.dayKey == past.rawValue }?.value ?? 0
        }
        let startedOn = DayKey(habit.startedAt, dayEndHour: FledgeSettings.dayEndHour)
        return NoDataHeuristic.shouldHint(
            todayValue: model.progress.value,
            previousValues: previous,
            daysActive: startedOn.days(to: day) + 1,
            hour: Calendar.current.component(.hour, from: .now)
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

    // MARK: - Amounts

    private var amountTitle: String {
        guard let habit = amountHabit else { return "" }
        return "Log \(habit.unit) for \(habit.name)"
    }

    private func logAmount() {
        guard let habit = amountHabit else { return }
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized), amount > 0 else {
            errorMessage = "Enter a number greater than zero."
            return
        }
        perform { try context.addAmount(amount, habitID: habit.id, on: day) }
    }

    #if DEBUG
    private func openDemoScreen() {
        guard DemoData.isEnabled, let screen = DemoData.screen else { return }
        let first = sortedHabits.first
        switch screen {
        case "detail": detailHabit = first
        case "graduation": graduatingHabit = first
        case "add": sheet = .add
        case "flown": sheet = .flown
        case "settings": sheet = .settings
        default: break
        }
    }
    #endif

    /// Runs a write; then reschedules reminders, and for structural changes (pause, delete, graduate)
    /// updates which Health types are observed.
    private func perform(structural: Bool = false, _ action: () throws -> Void) {
        do {
            try action()
            if structural {
                HealthSync.shared?.updateObservers()
            } else {
                Task { await Reminders.reconcile(context: context) }
            }
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one to add another."
        } catch HabitStoreError.noRestDaysLeft {
            errorMessage = "You've used this month's \(RestDayPolicy.freePassesPerMonth) rest days for this habit. Set it to a few days a week if you need more flexibility."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum TodaySheet: String, Identifiable {
    case add, flown, settings
    var id: String { rawValue }
}
