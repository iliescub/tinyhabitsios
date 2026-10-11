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
                ConfigureHabitView(initialDraft: route.draft) { draft in add(draft) }
            }
            .task { loadPack() }
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
                    NavigationLink(value: HabitDraftRoute(draft: HabitDraft(template: template, colorKey: defaultColorKey, packID: pack.id))) {
                        TemplateTile(template: template)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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

    private func add(_ draft: HabitDraft) {
        do {
            try context.addHabit(draft: draft)
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
    let onAdd: (HabitDraft) -> Void

    init(initialDraft: HabitDraft, onAdd: @escaping (HabitDraft) -> Void) {
        _draft = State(initialValue: initialDraft)
        self.onAdd = onAdd
    }

    var body: some View {
        HabitEditorView(draft: $draft)
            .navigationTitle(draft.trimmedName.isEmpty ? "New habit" : draft.trimmedName)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                PrimaryActionButton(title: "Add to nest", systemImage: "plus") { onAdd(draft) }
                    .disabled(draft.problem != nil)
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
