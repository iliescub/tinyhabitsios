import SwiftUI
import SwiftData
import StoreKit
import HabitCore
import FledgeUI

/// Today — "the Nest": the only screen. Everything else is a sheet or a cover (docs/DESIGN.md §5, §6.1).
struct TodayView: View {
    let day: DayKey

    @Environment(\.modelContext) private var context
    @Query private var activeHabits: [Habit]
    @Query private var todayLogs: [DayLog]
    @Query private var flownHabits: [Habit]
    /// RES-7: the current resolution (active or kept) sits above the nest.
    @Query(sort: \Resolution.createdAt, order: .reverse) private var resolutions: [Resolution]
    @Query private var allHabits: [Habit]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var sheet: TodaySheet?
    @State private var detailHabit: Habit?
    @State private var graduatingHabit: Habit?
    @State private var keptResolution: Resolution?
    /// Follow-ups presented from the dismissal of the cover/sheet before them, never with a timer (review finding).
    @State private var keptAfterGraduation: Resolution?
    @State private var newResolutionAfterSheet = false
    @State private var amountHabit: Habit?
    @State private var amountText = ""
    @State private var errorMessage: String?
    /// iPad split (docs/DESIGN.md §12): the window width and the habit shown in the detail pane.
    @State private var windowWidth: CGFloat = 0
    @State private var selectedHabitID: UUID?
    #if DEBUG
    @State private var shareCardHabit: Habit?
    @State private var showsWidgetGallery = false
    #endif
    @Environment(\.requestReview) private var requestReview
    @AppStorage("reviewRequested") private var reviewRequested = false

    init(day: DayKey) {
        self.day = day
        let active = HabitState.active.rawValue
        _activeHabits = Query(filter: #Predicate<Habit> { $0.stateRaw == active })
        let key = day.rawValue
        _todayLogs = Query(filter: #Predicate<DayLog> { $0.dayKey == key })
        let graduated = HabitState.graduated.rawValue
        _flownHabits = Query(filter: #Predicate<Habit> { $0.stateRaw == graduated })
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSplit {
                    HStack(spacing: 0) {
                        nest
                            .frame(width: NestLayout.nestColumnWidth(for: windowWidth))
                        detailPane
                    }
                    .background { selectionShortcuts }
                } else {
                    nest
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
            .onChange(of: NotificationRouter.shared.pending, initial: true) { _, route in
                // The slip nudge (GRAD-3) opens the Flown shelf, also when it launched the app.
                if route == .flown {
                    sheet = .flown
                    NotificationRouter.shared.pending = nil
                } else if route == .resolution {
                    // The letter on 1 December opens the resolution, where the letter is now open (RES-6).
                    sheet = currentResolution == nil ? nil : .resolution
                    NotificationRouter.shared.pending = nil
                }
            }
            .background(SkyBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { sheet = .flown } label: {
                        Label { Text("Flown") } icon: { Image.fledgeGlyph(height: 20) }
                    }
                    Button("Settings", systemImage: "gearshape") { sheet = .settings }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
            .sheet(item: $sheet, onDismiss: {
                if newResolutionAfterSheet {
                    newResolutionAfterSheet = false
                    sheet = .newResolution
                }
            }) { sheet in
                switch sheet {
                case .add: AddHabitSheet()
                case .flown: FlownSheet()
                case .settings: SettingsSheet()
                case .paywall: PaywallView()
                case .resolution:
                    if let resolution = currentResolution {
                        ResolutionSheet(resolution: resolution, day: day) {
                            newResolutionAfterSheet = true
                        }
                    }
                case .newResolution: NewResolutionSheet(day: day)
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
            #if DEBUG
            .sheet(item: $shareCardHabit) { habit in
                // `-FledgeDemoScreen sharecard`: the graduation share image, for review and App Store assets.
                let startedOn = DayKey(habit.startedAt, dayEndHour: FledgeSettings.dayEndHour)
                let snapshots = habit.logs?.compactMap(\.snapshot) ?? []
                let stats = HabitDetailStats(snapshots: snapshots, cadence: habit.cadence, startedOn: startedOn, today: day)
                ShareRecapCard(
                    name: habit.name, color: FledgeTheme.habitColor(habit.colorKey),
                    recap: RecapModel(
                        stats: stats, snapshots: snapshots, startedOn: startedOn, today: day,
                        target: habit.target, unit: habit.unit, perWeek: habit.perWeek
                    )
                )
                .presentationDetents([.large])
            }
            .fullScreenCover(isPresented: $showsWidgetGallery) {
                WidgetGallery(snapshot: NestSnapshot(context: context, day: day))
            }
            #endif
            .fullScreenCover(item: $keptResolution) { resolution in
                KeptView(resolution: resolution, day: day) {
                    keptResolution = nil
                    askForReviewOnce()
                }
            }
            .fullScreenCover(item: $graduatingHabit, onDismiss: {
                // RES-7: shown once the graduation cover has gone.
                if let resolution = keptAfterGraduation {
                    keptAfterGraduation = nil
                    keptResolution = resolution
                }
            }) { habit in
                GraduationView(habit: habit, day: day) {
                    let resolution = habit.resolutionID.flatMap { try? context.resolution(id: $0) }
                    let wasKept = resolution?.state == .kept
                    perform(structural: true) { try context.graduate(habitID: habit.id) }
                    // Kept only when this flight completed the resolution, not for one that was kept before.
                    if let resolution, !wasKept, resolution.state == .kept {
                        keptAfterGraduation = resolution
                    } else {
                        askForReviewOnce()
                    }
                    graduatingHabit = nil
                } onKeep: {
                    graduatingHabit = nil
                }
            }
            #if DEBUG
            .task {
                // A sheet presented during the very first appearance is sometimes dropped; wait for the screen to settle.
                try? await Task.sleep(for: .milliseconds(700))
                openDemoScreen()
            }
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

    /// The nest: header, week strip, three slots, the Flown preview, and Add floating at the bottom of the column.
    private var nest: some View {
        // Built once per pass: it reads every habit's logs for the year (review finding: it was rebuilt per card).
        let resolutionHeader = resolutionHeader
        return ScrollView {
            VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
                header
                if let offer = freshStartOffer, let resolution = currentResolution {
                    FreshStartCard(
                        offer: offer,
                        samePlan: { perform { try context.scheduleFreshStart(resolutionID: resolution.id, on: offer.day) } },
                        smallerSteps: { startSmaller(resolution: resolution, on: offer.day) },
                        notNow: { perform { try context.scheduleFreshStart(resolutionID: resolution.id, on: day) } }
                    )
                }
                if let resolutionHeader {
                    Button { sheet = .resolution } label: {
                        ResolutionCard(model: resolutionHeader)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens your year")
                } else if !activeHabits.isEmpty {
                    MakeResolutionCard { sheet = .newResolution }
                }
                if !activeHabits.isEmpty {
                    WeekStrip(model: weekModel)
                }
                ForEach(0..<SlotPolicy.maxActive, id: \.self) { slot in
                    if let habit = habit(inSlot: slot) {
                        card(for: habit, firstWeek: resolutionHeader?.isFirstWeek == true && habit.resolutionID == currentResolution?.id)
                    } else {
                        EmptySlotCard { sheet = .add }
                    }
                }
                FlownShelfRow(latest: latestFlown, total: flownHabits.count) { sheet = .flown }
                    .padding(.top, FledgeTheme.Space.s)
            }
            .padding(.horizontal, FledgeTheme.screenMargin)
            .padding(.bottom, FledgeTheme.Space.xxl)
        }
        .safeAreaInset(edge: .bottom) {
            if hasFreeSlot {
                PrimaryActionButton(title: "Add habit", systemImage: "plus") { sheet = .add }
                    .keyboardShortcut("n", modifiers: .command)
                    .padding(.bottom, FledgeTheme.Space.s)
            }
        }
    }

    // MARK: - iPad split (docs/DESIGN.md §12)

    private var isSplit: Bool {
        NestLayout.isSplit(width: windowWidth, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
    }

    /// The habit in the pane: the one picked, else the first in the nest.
    private var selectedHabit: Habit? {
        sortedHabits.first { $0.id == selectedHabitID } ?? sortedHabits.first
    }

    @ViewBuilder
    private var detailPane: some View {
        Group {
            if let habit = selectedHabit {
                HabitDetailSheet(habit: habit, day: day, style: .pane) { graduatingHabit = habit }
                    .id(habit.id)
            } else {
                ContentUnavailableView {
                    Label {
                        Text("Your nest is empty")
                    } icon: {
                        FledgeBird(.peeking, style: .glyph)
                            .foregroundStyle(FledgeTheme.Palette.ink2)
                            .frame(width: 84)
                    }
                } description: {
                    Text("Add a habit and its journey shows up here.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FledgeTheme.Palette.cloud.ignoresSafeArea())
        .overlay(alignment: .leading) {
            Rectangle().fill(FledgeTheme.Palette.hairline).frame(width: 1).ignoresSafeArea()
        }
    }

    /// ⌘1–⌘3 pick the habit in that slot.
    private var selectionShortcuts: some View {
        ForEach(Array(sortedHabits.prefix(3).enumerated()), id: \.element.id) { index, habit in
            Button("Show \(habit.name)") { selectedHabitID = habit.id }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Header

    /// Eyebrow date, the day's status as the title, the next step as the detail line, and the nest glyph (UX-5).
    private var header: some View {
        let cards = sortedHabits.map(model(for:))
        return HStack(alignment: .bottom, spacing: FledgeTheme.Space.l) {
            VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                Text(eyebrow)
                    .fledgeEyebrow()
                Text(TodaySummary.title(for: cards))
                    .font(FledgeTheme.Typeface.title)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                    .contentTransition(.numericText())
                Text(TodaySummary.detail(for: cards))
                    .font(.subheadline)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if !dynamicTypeSize.isAccessibilitySize && !cards.isEmpty {
                NestGlyph(rings: cards.map {
                    NestGlyph.Ring(fraction: $0.progress.fraction, status: $0.progress.status, color: FledgeTheme.habitColor($0.colorKey))
                })
                .frame(width: 60, height: 60)
                .padding(.bottom, FledgeTheme.Space.xs)
            }
        }
        .padding(.top, FledgeTheme.Space.s)
        .animation(.snappy, value: cards.map(\.progress.status))
    }

    /// "Wednesday · 14 Oct"
    private var eyebrow: String {
        let date = day.date()
        return "\(date.formatted(.dateTime.weekday(.wide))) · \(date.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private var currentResolution: Resolution? {
        resolutions.first { $0.state != .archived }
    }

    private var resolutionHeader: ResolutionHeaderModel? {
        currentResolution.flatMap { ResolutionHeaderModel(resolution: $0, habits: allHabits, today: day) }
    }

    /// RES-5 / UXR-3: after a quiet week, offer the next Monday or 1st instead of a broken streak. Once per lapse.
    private var freshStartOffer: FreshStart.Offer? {
        guard let resolution = currentResolution, resolution.state == .active, let start = resolution.startDay else { return nil }
        let habits = activeHabits.filter { $0.resolutionID == resolution.id }
        let lapsed = FreshStart.hasLapsed(
            habits: habits.map { habit in
                FreshStart.Habit(
                    perWeek: habit.perWeek, startedOn: DayKey(habit.startedAt, dayEndHour: FledgeSettings.dayEndHour),
                    snapshots: habit.logs?.compactMap(\.snapshot) ?? []
                )
            },
            startedOn: start, today: day
        )
        guard FreshStart.shouldOffer(lapsed: lapsed, lastFreshStart: DayKey(rawValue: resolution.freshStartDayKey), today: day) else {
            return nil
        }
        return FreshStart.nextLandmark(after: day)
    }

    /// "Smaller steps": halve each goal of the resolution's habits on the stepper's grid, then record the fresh start.
    private func startSmaller(resolution: Resolution, on freshDay: DayKey) {
        perform {
            for habit in activeHabits where habit.resolutionID == resolution.id && habit.target > 1 {
                var draft = HabitDraft(habit: habit)
                draft.target = FreshStart.smallerTarget(habit.target, step: TargetSteps.step(for: habit.unit))
                try context.updateHabit(habitID: habit.id, with: draft, reevaluating: day)
            }
            try context.scheduleFreshStart(resolutionID: resolution.id, on: freshDay)
        }
    }

    private var weekModel: WeekModel {
        WeekModel(habits: sortedHabits.map { habit in
            WeekModel.Habit(
                colorKey: habit.colorKey,
                startedOn: DayKey(habit.startedAt, dayEndHour: FledgeSettings.dayEndHour),
                snapshots: habit.logs?.compactMap(\.snapshot) ?? []
            )
        }, today: day)
    }

    private var latestFlown: Habit? {
        flownHabits.max { ($0.graduatedAt ?? .distantPast) < ($1.graduatedAt ?? .distantPast) }
    }

    // MARK: - Cards

    private func card(for habit: Habit, firstWeek: Bool) -> some View {
        let model = model(for: habit)
        let isDone = model.progress.status == .done
        return HabitCardView(
            model: model,
            actions: HabitCardActions(
                open: {
                    if isSplit { selectedHabitID = habit.id } else { detailHabit = habit }
                },
                toggleDone: {
                    perform { try context.setDone(!isDone, habitID: habit.id, on: day, by: .manual) }
                    if !isDone { askForReviewAfterAWeek() }
                },
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
            showsNoDataHint: showsNoDataHint(for: habit, model: model),
            cue: habit.cue,
            firstWeek: firstWeek,
            missedYesterday: MissCheck.missedOnlyYesterday(
                snapshots: habit.logs?.compactMap(\.snapshot) ?? [], perWeek: habit.perWeek,
                startedOn: DayKey(habit.startedAt, dayEndHour: FledgeSettings.dayEndHour), today: day
            ),
            isSelected: isSplit && selectedHabit?.id == habit.id,
            lastUpdated: habit.source.isAuto ? todayLogs.first { $0.habit?.id == habit.id }?.updatedAt : nil
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

    // MARK: - Review prompt (REV-1): after 7 days with something done, or the first graduation. Once.

    private func askForReviewAfterAWeek() {
        let doneDays = Set(activeHabits.flatMap { $0.logs ?? [] }.filter { $0.status == .done }.map(\.dayKey))
        if doneDays.count >= 7 { askForReviewOnce() }
    }

    private func askForReviewOnce() {
        guard !reviewRequested else { return }
        reviewRequested = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            requestReview()
        }
    }

    #if DEBUG
    private func openDemoScreen() {
        guard DemoData.isEnabled, let screen = DemoData.screen else { return }
        let first = sortedHabits.first
        switch screen {
        case "detail": detailHabit = first
        case "detail-2", "detail-3":
            let index = screen == "detail-2" ? 1 : 2
            detailHabit = sortedHabits.indices.contains(index) ? sortedHabits[index] : first
        case "graduation": graduatingHabit = first
        case "add", "configure": sheet = .add
        case "flown": sheet = .flown
        case "settings": sheet = .settings
        case "paywall": sheet = .paywall
        case "sharecard": shareCardHabit = first
        case "widgets": showsWidgetGallery = true
        case "resolution": sheet = .resolution
        case "newresolution": sheet = .newResolution
        case "kept": keptResolution = currentResolution
        default: break
        }
    }
    #endif

    /// Runs a write; then reschedules reminders, and for structural changes (pause, delete, graduate)
    /// updates which Health types are observed.
    private func perform(structural: Bool = false, _ action: () throws -> Void) {
        do {
            try action()
            AppRefresh.afterWrite(context: context, structural: structural)
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one to add another."
        } catch HabitStoreError.noRestDaysLeft {
            errorMessage = "You've used this month's \(RestDayPolicy.freePassesPerMonth) rest days for this habit. Set it to a few days a week if you need more flexibility."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// The Flown shelf preview under the cards: the latest graduate, or a hint about day 30 (UX-5).
struct FlownShelfRow: View {
    let latest: Habit?
    let total: Int
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: FledgeTheme.Space.m) {
                Group {
                    if let latest {
                        FledgeBird(style: .tinted(FledgeTheme.habitColor(latest.colorKey)))
                    } else {
                        FledgeBird(.peeking, style: .glyph)
                            .foregroundStyle(FledgeTheme.Palette.ink2.opacity(0.6))
                    }
                }
                .frame(width: 36, height: 30)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FledgeTheme.Palette.ink2.opacity(0.6))
            }
            .padding(.horizontal, FledgeTheme.Space.l)
            .padding(.vertical, FledgeTheme.Space.m)
            .overlay {
                RoundedRectangle(cornerRadius: FledgeTheme.Radius.tile, style: .continuous)
                    .strokeBorder(FledgeTheme.Palette.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            }
            .contentShape(.rect(cornerRadius: FledgeTheme.Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens the Flown shelf"))
    }

    private var text: String {
        let days = latest.flatMap { habit in
            habit.graduatedAt.map { DayKey(habit.startedAt).days(to: DayKey($0)) + 1 }
        }
        return FlownPreview.text(latestName: latest?.name, flewOn: latest?.graduatedAt, days: days, total: total)
    }
}

enum TodaySheet: String, Identifiable {
    case add, flown, settings, paywall, resolution, newResolution
    var id: String { rawValue }
}
