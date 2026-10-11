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

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: FledgeTheme.Space.m)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                if let pack {
                    VStack(alignment: .leading, spacing: FledgeTheme.Space.xl) {
                        section(
                            "Done for you",
                            subtitle: "Completes itself from Apple Health.",
                            templates: pack.templates.filter { $0.source.isAuto },
                            pack: pack
                        )
                        section(
                            "Tap to log",
                            subtitle: "One tap from the card or a widget.",
                            templates: pack.templates.filter { !$0.source.isAuto },
                            pack: pack
                        )
                        Button {
                            path.append(HabitDraftRoute(draft: HabitDraft(colorKey: defaultColorKey, packID: pack.id)))
                        } label: {
                            Label("Custom habit", systemImage: "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(FledgeTheme.Palette.card, in: .rect(cornerRadius: FledgeTheme.Radius.tile))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(FledgeTheme.Palette.skyText)
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

    private func section(_ title: String, subtitle: String, templates: [Pack.Template], pack: Pack) -> some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.bold()).fontDesign(.rounded).foregroundStyle(FledgeTheme.Palette.ink)
                Text(subtitle).font(.subheadline).foregroundStyle(FledgeTheme.Palette.ink2)
            }
            LazyVGrid(columns: columns, spacing: FledgeTheme.Space.m) {
                ForEach(templates, id: \.name) { template in
                    if template.source.isAuto && !canAddAuto {
                        Button { showPaywall = true } label: {
                            TemplateTile(template: template).overlay(alignment: .topTrailing) { ProBadge().padding(FledgeTheme.Space.s) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Needs Fledge Pro")
                    } else {
                        NavigationLink(value: HabitDraftRoute(draft: HabitDraft(template: template, colorKey: defaultColorKey, packID: pack.id))) {
                            TemplateTile(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Free tier: one active habit from Apple Health (PAY-2).
    private var canAddAuto: Bool {
        let activeAuto = ((try? context.activeHabits()) ?? []).filter { $0.source.isAuto }.count
        return ProPolicy.canAddAutoHabit(isPro: purchases.isPro, activeAutoCount: activeAuto)
    }

    private var defaultColorKey: String {
        let occupied = Set((try? context.activeHabits())?.compactMap(\.slot) ?? [])
        return FledgeTheme.defaultColorKey(forSlot: SlotPolicy.nextFreeSlot(occupied: occupied) ?? 0)
    }

    private func loadPack() {
        do {
            pack = try PackLibrary.essentials()
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
            try context.addHabit(draft: draft)
            AppRefresh.afterWrite(context: context, structural: true)
            dismiss()
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
    let isBusy: Bool
    let onAdd: (HabitDraft) -> Void

    init(initialDraft: HabitDraft, isBusy: Bool, onAdd: @escaping (HabitDraft) -> Void) {
        _draft = State(initialValue: initialDraft)
        self.isBusy = isBusy
        self.onAdd = onAdd
    }

    var body: some View {
        HabitEditorView(draft: $draft)
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

struct TemplateTile: View {
    let template: Pack.Template

    var body: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
            Image(systemName: template.symbol)
                .font(.title2)
                .foregroundStyle(FledgeTheme.Palette.sky)
                .symbolRenderingMode(.hierarchical)
                .frame(height: 30, alignment: .leading)
            Text(template.name)
                .font(.headline)
                .foregroundStyle(FledgeTheme.Palette.ink)
            Text(targetText)
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.ink2)
            Spacer(minLength: 0)
            if template.source.isAuto {
                SourceBadge(isAuto: true)
            }
        }
        .padding(FledgeTheme.Space.l)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(FledgeTheme.Palette.card, in: .rect(cornerRadius: FledgeTheme.Radius.tile))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Choose and adjust this habit")
    }

    private var targetText: String {
        let amount = template.target.formatted(.number.precision(.fractionLength(0...1)))
        let isOnce = template.target <= 1 && template.unit == "times"
        if let perWeek = template.perWeek, perWeek < 7 {
            return "\(isOnce ? "Once" : "\(amount) \(template.unit)") · \(perWeek)× a week"
        }
        return isOnce ? "Once a day" : "\(amount) \(template.unit) a day"
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

/// Primary call to action; Liquid Glass on iOS 26, prominent bordered before.
struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        let button = Button(action: action) {
            Label(title, systemImage: systemImage)
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
