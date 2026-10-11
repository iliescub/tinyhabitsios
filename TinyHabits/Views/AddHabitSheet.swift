import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// Pick a template from the Essentials pack (docs/DESIGN.md §6.3). The configure step comes in LOOP-2.
struct AddHabitSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var pack: Pack?
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: FledgeTheme.Space.m)]

    var body: some View {
        NavigationStack {
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
                    Button { add(template, from: pack) } label: { TemplateTile(template: template) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadPack() {
        do {
            pack = try PackLibrary.essentials()
        } catch {
            errorMessage = "The habit templates couldn't be loaded."
        }
    }

    private func add(_ template: Pack.Template, from pack: Pack) {
        do {
            let occupied = Set(try context.activeHabits().compactMap(\.slot))
            let slot = SlotPolicy.nextFreeSlot(occupied: occupied) ?? 0
            try context.addHabit(from: template, colorKey: FledgeTheme.defaultColorKey(forSlot: slot), packID: pack.id)
            dismiss()
        } catch HabitStoreError.nestFull {
            errorMessage = "Your nest holds three. Let one fly or pause one to add another."
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
        .accessibilityHint("Adds this habit to your nest")
    }

    private var targetText: String {
        let amount = template.target.formatted(.number.precision(.fractionLength(0...1)))
        let base = template.target <= 1 && template.unit == "times" ? "Once" : "\(amount) \(template.unit)"
        if let perWeek = template.perWeek, perWeek < 7 {
            return "\(base) · \(perWeek)× a week"
        }
        return template.target <= 1 && template.unit == "times" ? "Once a day" : "\(base) a day"
    }
}
