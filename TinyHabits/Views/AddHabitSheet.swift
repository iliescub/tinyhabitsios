import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// Add habit: pick a template (or custom), then configure (docs/DESIGN.md §6.3).
struct AddHabitSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var pack: Pack?
    @State private var path: [HabitDraftRoute] = []
    @State private var errorMessage: String?
    @State private var noDataDraft: HabitDraft?
    @State private var isPreparing = false
    @State private var showPaywall = false
    @State private var purchases = Purchases.shared

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if let pack {
                    VStack(alignment: .leading, spacing: FledgeTheme.Space.xl) {
                        if !canAddAuto {
                            ProBanner(usedOn: activeHabits.first { $0.source.isAuto }?.name) { showPaywall = true }
                        }
                        if DeviceInfo.isHealthAvailable {
                            section(
                                "Done for you",
                                subtitle: "Completes itself from Apple Health.",
                                symbol: "heart.fill",
                                templates: pack.templates.filter { $0.source.isAuto },
                                pack: pack
                            )
                        } else {
                            section(
                                "Usually from Apple Health",
                                subtitle: "Apple Health isn't available on this \(DeviceInfo.name), so these are logged by tapping.",
                                symbol: "heart.slash",
                                templates: pack.templates.filter { $0.source.isAuto }.map(\.tapToLog),
                                pack: pack
                            )
                        }
                        section(
                            "Tap to log",
                            subtitle: "One tap from the card, a widget or Siri.",
                            symbol: "hand.tap.fill",
                            templates: pack.templates.filter { !$0.source.isAuto },
                            pack: pack,
                            custom: true
                        )
                    }
                    .padding(FledgeTheme.screenMargin)
                }
            }
            .background(FledgeTheme.Palette.cloud)
            .navigationTitle("Add a habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .navigationDestination(for: HabitDraftRoute.self) { route in
                ConfigureHabitView(initialDraft: route.draft, isBusy: isPreparing) { draft in
                    Task { await prepareAndAdd(draft) }
                }
            }
            .task { loadPack() }
            .sheet(isPresented: $showPaywall) { PaywallView(reason: .secondHealthHabit) }
            .alert(
                "No recent data in Apple Health",
                isPresented: Binding(get: { noDataDraft != nil }, set: { if !$0 { noDataDraft = nil } })
            ) {
                Button("Keep Apple Health") {
                    if let draft = noDataDraft { add(draft) }
                }
                Button("Track by tapping instead") {
                    if var draft = noDataDraft {
                        draft.source = .manual
                        draft.unit = "times"
                        draft.target = 1
                        add(draft)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Fledge found no \(noDataDraft?.name ?? "") data from the last 7 days. If you don't track it with your iPhone or Apple Watch, tap to log it instead. You can also check access in the Health app.")
            }
            .alert("Couldn't add habit", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    /// A titled group of template rows in one card (UX-9).
    private func section(
        _ title: String, subtitle: String, symbol: String, templates: [Pack.Template], pack: Pack, custom: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Label(title, systemImage: symbol)
                    .font(.title3.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(FledgeTheme.Palette.ink)
                    .labelStyle(SectionLabelStyle())
                Text(subtitle).font(.subheadline).foregroundStyle(FledgeTheme.Palette.ink2)
            }
            VStack(spacing: 0) {
                ForEach(Array(templates.enumerated()), id: \.element.name) { index, template in
                    templateRow(template, pack: pack)
                    if index < templates.count - 1 || custom {
                        Divider().padding(.leading, 64)
                    }
                }
                if custom {
                    NavigationLink(value: HabitDraftRoute(draft: HabitDraft(colorKey: newColorKey, packID: pack.id))) {
                        TemplateRow(
                            symbol: "plus", color: FledgeTheme.Palette.ink2, title: "Your own habit",
                            subtitle: "Name, icon and goal", trailing: .chevron
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
        }
    }

    @ViewBuilder
    private func templateRow(_ template: Pack.Template, pack: Pack) -> some View {
        let color = FledgeTheme.habitColor(TemplateStyle.colorKey(for: template))
        let subtitle = TemplateStyle.targetText(for: template)
        if activeHabits.contains(where: { $0.name == template.name }) {
            TemplateRow(symbol: template.symbol, color: color, title: template.name, subtitle: subtitle, trailing: .inNest)
                .accessibilityHint("Already in your nest")
        } else if template.source.isAuto && !canAddAuto {
            Button { showPaywall = true } label: {
                TemplateRow(symbol: template.symbol, color: color, title: template.name, subtitle: subtitle, trailing: .locked)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Needs Fledge Pro")
        } else {
            NavigationLink(value: HabitDraftRoute(draft: draft(for: template, pack: pack))) {
                TemplateRow(symbol: template.symbol, color: color, title: template.name, subtitle: subtitle, trailing: .chevron)
            }
            .buttonStyle(.plain)
        }
    }

    private var activeHabits: [Habit] {
        (try? context.activeHabits()) ?? []
    }

    private var nextSlot: Int {
        SlotPolicy.nextFreeSlot(occupied: Set(activeHabits.compactMap(\.slot))) ?? 0
    }

    private func draft(for template: Pack.Template, pack: Pack) -> HabitDraft {
        let colorKey = TemplateStyle.preferredColorKey(for: template, taken: Set(activeHabits.map(\.colorKey)), slot: nextSlot)
        return HabitDraft(template: template, colorKey: colorKey, packID: pack.id)
    }

    /// A free colour for a custom habit.
    private var newColorKey: String {
        let taken = Set(activeHabits.map(\.colorKey))
        let slotDefault = FledgeTheme.defaultColorKey(forSlot: nextSlot)
        return taken.contains(slotDefault) ? (FledgeTheme.habitColorKeys.first { !taken.contains($0) } ?? slotDefault) : slotDefault
    }

    /// Free tier: one active habit from Apple Health (PAY-2).
    private var canAddAuto: Bool {
        let activeAuto = activeHabits.filter { $0.source.isAuto }.count
        return ProPolicy.canAddAutoHabit(isPro: purchases.isPro, activeAutoCount: activeAuto)
    }

    private func loadPack() {
        do {
            let loaded = try PackLibrary.essentials()
            pack = loaded
            #if DEBUG
            // `-FledgeDemoScreen configure`: open the configure step for the first template not in the nest.
            if DemoData.screen == "configure",
               let template = loaded.templates.first(where: { t in !activeHabits.contains { $0.name == t.name } }) {
                path = [HabitDraftRoute(draft: draft(for: template, pack: loaded))]
            }
            #endif
        } catch {
            errorMessage = "The habit templates couldn't be loaded."
        }
    }

    /// Health habits: ask for read access first and offer manual tracking when Health has no recent data (HK-4).
    private func prepareAndAdd(_ draft: HabitDraft) async {
        if draft.reminderMinutes != nil {
            await Reminders.requestAuthorizationIfNeeded()
        }
        if draft.source.isAuto && !canAddAuto {
            showPaywall = true
            return
        }
        guard draft.source.isAuto, let sync = HealthSync.shared else {
            add(draft)
            return
        }
        isPreparing = true
        let result = await sync.prepare(source: draft.source, unit: draft.unit)
        isPreparing = false
        if result.metric != nil && !result.hasRecentData {
            noDataDraft = draft
        } else {
            add(draft)
        }
    }

    private func add(_ draft: HabitDraft) {
        do {
            let habit = try context.addHabit(draft: draft)
            AppRefresh.afterWrite(context: context, structural: true)
            dismiss()
            Task { await HeadStart.backfill(habit) }
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one to add another."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HabitDraftRoute: Hashable {
    let id = UUID()
    let draft: HabitDraft

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Configure step before adding.
struct ConfigureHabitView: View {
    @State private var draft: HabitDraft
    @State private var headStart: HeadStartState = .none
    let isBusy: Bool
    let onAdd: (HabitDraft) -> Void

    init(initialDraft: HabitDraft, isBusy: Bool, onAdd: @escaping (HabitDraft) -> Void) {
        _draft = State(initialValue: initialDraft)
        self.isBusy = isBusy
        self.onAdd = onAdd
    }

    var body: some View {
        HabitEditorView(draft: $draft, headStart: headStart)
            .task {
                // HEAD-1: read the last 30 days for Health habits (asks for read access the first time).
                guard draft.source.isAuto, headStart == .none else { return }
                headStart = .loading
                if let values = await HeadStart.values(source: draft.source, unit: draft.unit) {
                    headStart = .values(values)
                } else {
                    headStart = .none
                }
            }
            .navigationTitle(draft.trimmedName.isEmpty ? "New habit" : draft.trimmedName)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                PrimaryActionButton(title: isBusy ? "Connecting to Health…" : "Add to nest", systemImage: "plus") { onAdd(draft) }
                    .disabled(draft.problem != nil || isBusy)
                    .padding(.bottom, FledgeTheme.Space.s)
            }
    }
}

/// Edit an existing habit (from the detail sheet).
struct EditHabitSheet: View {
    let habit: Habit
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: HabitDraft
    @State private var errorMessage: String?

    init(habit: Habit) {
        self.habit = habit
        _draft = State(initialValue: HabitDraft(habit: habit))
    }

    var body: some View {
        NavigationStack {
            HabitEditorView(draft: $draft)
                .navigationTitle("Edit habit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(draft.problem != nil)
                    }
                }
                .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    private func save() {
        do {
            try context.updateHabit(habitID: habit.id, with: draft)
            let needsNotifications = draft.reminderMinutes != nil
            AppRefresh.afterWrite(context: context, structural: true)
            if needsNotifications {
                Task { await Reminders.requestAuthorizationIfNeeded() }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// One template in Add or onboarding: coloured icon square, name, goal, and what tapping does (UX-9).
struct TemplateRow: View {
    enum Trailing: Equatable {
        case chevron, locked, inNest, none
        case selectable(Bool)
    }

    let symbol: String
    let color: Color
    let title: String
    let subtitle: String
    let trailing: Trailing

    var body: some View {
        HStack(spacing: FledgeTheme.Space.m) {
            IconSquare(symbol: symbol, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(FledgeTheme.Palette.ink)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailingView
        }
        .padding(.horizontal, FledgeTheme.Space.l)
        .padding(.vertical, FledgeTheme.Space.m)
        .contentShape(.rect)
        .opacity(trailing == .inNest ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(trailing == .selectable(true) ? .isSelected : [])
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FledgeTheme.Palette.ink2.opacity(0.6))
        case .locked:
            ProBadge()
        case .inNest:
            Text("In the nest")
                .font(FledgeTheme.Typeface.meta)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        case .none:
            EmptyView()
        case .selectable(let isOn):
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isOn ? color : FledgeTheme.Palette.hairline)
                .contentTransition(.symbolEffect(.replace))
        }
    }
}

/// The one explanation of the free tier, replacing a Pro badge on every Health template (UX-9).
struct ProBanner: View {
    let usedOn: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FledgeTheme.Space.m) {
                FledgeBird()
                    .frame(width: 40)
                    .padding(6)
                    .background(FledgeTheme.Palette.sky, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(usedOn.map { "Your free Health habit is \($0)." } ?? "Free includes one Health habit.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Text("Fledge Pro lets all three fill in by themselves.")
                        .font(.footnote)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(FledgeTheme.Palette.ink2.opacity(0.6))
            }
            .padding(FledgeTheme.Space.l)
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile, tint: FledgeTheme.Palette.gold)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Fledge Pro")
    }
}

/// Section title with a small coloured symbol in front.
struct SectionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: FledgeTheme.Space.s) {
            configuration.icon
                .font(.subheadline)
                .foregroundStyle(FledgeTheme.Palette.ink2)
            configuration.title
        }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.caption.bold())
            .padding(.horizontal, FledgeTheme.Space.s)
            .padding(.vertical, 2)
            .background(FledgeTheme.Palette.gold.opacity(0.2), in: .capsule)
            .foregroundStyle(FledgeTheme.Palette.ink)
    }
}

/// Primary call to action: ink (UX-1). Liquid Glass prominent tinted ink on iOS 26, `FledgePrimaryButtonStyle` before.
struct PrimaryActionButton: View {
    let title: String
    let icon: Image
    let action: () -> Void

    init(title: String, systemImage: String, action: @escaping () -> Void) {
        self.init(title: title, icon: Image(systemName: systemImage), action: action)
    }

    init(title: String, icon: Image, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        let label = Label { Text(title) } icon: { icon }

        if #available(iOS 26, *) {
            Button(action: action) {
                label
                    .font(.headline)
                    .foregroundStyle(FledgeTheme.Palette.onInk)
                    .padding(.horizontal, FledgeTheme.Space.s)
                    .padding(.vertical, FledgeTheme.Space.xs)
            }
            .buttonBorderShape(.capsule)
            .tint(FledgeTheme.Palette.ink)
            .buttonStyle(.glassProminent)
        } else {
            Button(action: action) { label }
                .buttonStyle(FledgePrimaryButtonStyle())
        }
    }
}
