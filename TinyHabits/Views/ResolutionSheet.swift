import SwiftUI
import SwiftData
import HabitCore
import FledgeUI

/// The resolution in full (UXR-5, RES-6): the year grid, the letter (sealed until 1 December or Kept), editing, and
/// letting it go or starting the next one. Opened by tapping the resolution card on Today.
struct ResolutionSheet: View {
    let resolution: Resolution
    let day: DayKey
    /// Opens the new-resolution sheet (after this one is dismissed).
    let startNext: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allHabits: [Habit]
    @State private var editing = false
    @State private var draft = ResolutionDraft()
    @State private var confirmLetGo = false
    @State private var showsLetter = false
    @State private var errorMessage: String?

    private var habits: [Habit] { allHabits.filter { $0.resolutionID == resolution.id } }
    private var isKept: Bool { resolution.state == .kept }
    private var letterOpen: Bool { ResolutionYear.isLetterOpen(today: day, year: resolution.year, kept: isKept) }

    private var header: ResolutionHeaderModel? {
        ResolutionHeaderModel(resolution: resolution, habits: allHabits, today: day)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FledgeTheme.Space.l) {
                    if let header {
                        VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                            Text(header.sentence)
                                .font(FledgeTheme.Typeface.title)
                                .foregroundStyle(FledgeTheme.Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if !header.why.isEmpty {
                                Text(header.why).font(.subheadline.italic()).foregroundStyle(FledgeTheme.Palette.ink2)
                            }
                            Text(header.progressLine).font(FledgeTheme.Typeface.meta).foregroundStyle(FledgeTheme.Palette.ink2)
                        }
                        YearGrid(model: YearGridModel(year: resolution.year, dots: header.dots), kept: isKept)
                            .padding(FledgeTheme.Space.l)
                            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
                    }
                    habitsSection
                    letterSection
                    actions
                }
                .padding(.horizontal, FledgeTheme.screenMargin)
                .padding(.vertical, FledgeTheme.Space.l)
                .frame(maxWidth: NestLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(FledgeTheme.Palette.cloud)
            .navigationTitle("Your \(String(resolution.year))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    if !isKept && resolution.state != .archived {
                        Button("Edit") { startEditing() }
                    }
                }
            }
            .sheet(isPresented: $editing) { editor }
            .sheet(isPresented: $showsLetter) { LetterView(resolution: resolution) }
            .confirmationDialog("Let \u{201C}\(resolution.text)\u{201D} go?", isPresented: $confirmLetGo, titleVisibility: .visible) {
                Button("Let it go", role: .destructive) { letGo() }
            } message: {
                Text("Its habits stay in your nest. You can start a new resolution any Monday or 1st of the month.")
            }
            .alert("Couldn't do that", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var habitsSection: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
            Text("Its habits").fledgeEyebrow()
            VStack(spacing: 0) {
                if habits.isEmpty {
                    Text("No habits yet. Add up to three from Today.")
                        .font(.subheadline).foregroundStyle(FledgeTheme.Palette.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FledgeTheme.Space.l)
                }
                ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                    HStack(spacing: FledgeTheme.Space.m) {
                        IconSquare(symbol: habit.symbol, color: FledgeTheme.habitColor(habit.colorKey))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(habit.name).font(.body.weight(.semibold)).foregroundStyle(FledgeTheme.Palette.ink)
                            Text(habit.cue.isEmpty ? stateText(habit) : "\(habit.cue) · \(stateText(habit))")
                                .font(.footnote).foregroundStyle(FledgeTheme.Palette.ink2)
                        }
                        Spacer(minLength: 0)
                        if habit.state == .graduated {
                            Image.fledgeGlyph(height: 18).accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal, FledgeTheme.Space.l)
                    .padding(.vertical, FledgeTheme.Space.m)
                    .accessibilityElement(children: .combine)
                    if index < habits.count - 1 { Divider().padding(.leading, 64) }
                }
            }
            .fledgeCard(cornerRadius: FledgeTheme.Radius.tile)
        }
    }

    private func stateText(_ habit: Habit) -> String {
        switch habit.state {
        case .active: "In the nest"
        case .graduated: "Flown"
        case .paused: "Paused"
        }
    }

    @ViewBuilder
    private var letterSection: some View {
        if !resolution.letter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button {
                if letterOpen { showsLetter = true }
            } label: {
                HStack(spacing: FledgeTheme.Space.m) {
                    Image(systemName: letterOpen ? "envelope.open.fill" : "envelope.fill")
                        .font(.title2)
                        .foregroundStyle(FledgeTheme.Palette.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(letterOpen ? "Your letter is open" : "Sealed until 1 December")
                            .font(.headline).foregroundStyle(FledgeTheme.Palette.ink)
                        Text(letterOpen ? "Read what you wrote when you started." : "It opens earlier if your resolution is kept.")
                            .font(.footnote).foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                    Spacer(minLength: 0)
                    if letterOpen {
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                }
                .padding(FledgeTheme.Space.l)
                .fledgeCard(cornerRadius: FledgeTheme.Radius.tile, tint: FledgeTheme.Palette.gold)
            }
            .buttonStyle(.plain)
            .disabled(!letterOpen)
            .accessibilityHint(letterOpen ? "Opens the letter" : "")
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
            if isKept || resolution.state == .archived {
                PrimaryActionButton(title: "Start your next resolution", systemImage: "sunrise.fill") {
                    dismiss()
                    startNext()
                }
                .frame(maxWidth: .infinity)
            } else {
                Button("Let this resolution go") { confirmLetGo = true }
                    .font(.footnote)
                    .tint(FledgeTheme.Palette.skyText)
            }
        }
        .padding(.top, FledgeTheme.Space.s)
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section("Resolution") {
                    TextField("In \(String(resolution.year)) I want to…", text: $draft.text)
                }
                Section("Why it matters") {
                    TextField("Why it matters", text: $draft.why, axis: .vertical).lineLimit(2...4)
                }
                if !letterOpen {
                    Section {
                        TextField("Dear December me…", text: $draft.letter, axis: .vertical).lineLimit(4...8)
                    } header: {
                        Text("Letter to December")
                    } footer: {
                        Text("Sealed until 1 December, or the day your resolution is kept.")
                    }
                }
                if let problem = draft.problem {
                    Text(message(for: problem)).font(.footnote).foregroundStyle(FledgeTheme.Palette.ink2)
                }
            }
            .navigationTitle("Edit resolution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editing = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(draft.problem != nil)
                }
            }
        }
    }

    private func message(for problem: ResolutionDraft.Problem) -> String {
        switch problem {
        case .emptyText: "Write your resolution in a few words."
        case .textTooLong: "Keep it under \(ResolutionDraft.maxTextLength) characters."
        case .whyTooLong: "Keep the reason under \(ResolutionDraft.maxWhyLength) characters."
        case .letterTooLong: "Keep the letter under \(ResolutionDraft.maxLetterLength) characters."
        }
    }

    private func startEditing() {
        draft = ResolutionDraft(text: resolution.text, templateID: resolution.templateID, why: resolution.why, letter: resolution.letter)
        editing = true
    }

    private func save() {
        // A changed resolution text no longer matches its template sentence.
        if draft.trimmedText != resolution.text { draft.templateID = "" }
        do {
            try context.updateResolution(id: resolution.id, with: draft)
            AppRefresh.afterWrite(context: context)
            editing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func letGo() {
        do {
            try context.archiveResolution(id: resolution.id)
            AppRefresh.afterWrite(context: context)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// 12 columns (months) × 31 rows (days): full = filled square, partial = lower half filled, empty = outline,
/// later days = faint. Shape carries the state too, not colour alone (UXR-8).
struct YearGrid: View {
    let model: YearGridModel
    var kept = false

    private let letters = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    var body: some View {
        let color = kept ? FledgeTheme.Palette.gold : FledgeTheme.Palette.meadow
        VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                GridRow {
                    ForEach(0..<12, id: \.self) { month in
                        Text(letters[month]).font(.caption2.weight(.semibold)).foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                }
                ForEach(0..<31, id: \.self) { day in
                    GridRow {
                        ForEach(0..<12, id: \.self) { month in
                            let dots = model.months[month].dots
                            if day < dots.count {
                                cell(dots[day], color: color)
                            } else {
                                Color.clear.frame(width: 11, height: 11)
                            }
                        }
                    }
                }
            }
            HStack(spacing: FledgeTheme.Space.l) {
                legend("All met") { RoundedRectangle(cornerRadius: 2).fill(color) }
                legend("Some") { halfCell(color) }
                legend("None") { RoundedRectangle(cornerRadius: 2).strokeBorder(FledgeTheme.Palette.ink2.opacity(0.5), lineWidth: 1) }
            }
            .font(.caption2)
            .foregroundStyle(FledgeTheme.Palette.ink2)
            Text("\(model.metDays) days with your habits so far, \(model.fullDays) with all of them.")
                .font(.footnote)
                .foregroundStyle(FledgeTheme.Palette.ink2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var accessibilityText: String {
        let months = model.months.filter { $0.metDays > 0 }.map { month in
            let name = DayKey(year: model.year, month: month.number, day: 1).date().formatted(.dateTime.month(.wide))
            return "\(name): \(month.metDays) days"
        }
        let detail = months.isEmpty ? "" : " " + months.joined(separator: ", ") + "."
        return "Your \(model.year): \(model.metDays) days with your habits, \(model.fullDays) with all of them.\(detail)"
    }

    @ViewBuilder
    private func cell(_ dot: YearMap.Dot, color: Color) -> some View {
        Group {
            switch dot {
            case .full: RoundedRectangle(cornerRadius: 2).fill(color)
            case .partial: halfCell(color)
            case .empty: RoundedRectangle(cornerRadius: 2).strokeBorder(FledgeTheme.Palette.ink2.opacity(0.5), lineWidth: 1)
            case .future: RoundedRectangle(cornerRadius: 2).fill(FledgeTheme.Palette.ink.opacity(0.06))
            case .before: Color.clear
            }
        }
        .frame(width: 11, height: 11)
        .frame(maxWidth: .infinity)
    }

    private func halfCell(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .strokeBorder(color, lineWidth: 1)
            .background(alignment: .bottom) {
                GeometryReader { proxy in
                    Rectangle().fill(color).frame(height: proxy.size.height / 2).frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .clipShape(.rect(cornerRadius: 2))
    }

    private func legend(_ title: String, @ViewBuilder swatch: () -> some View) -> some View {
        HStack(spacing: 4) {
            swatch().frame(width: 10, height: 10)
            Text(title)
        }
    }
}

/// The letter to December (RES-6, UXR-7): an envelope first, then the letter and the reason.
struct LetterView: View {
    let resolution: Resolution

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = false

    var body: some View {
        ZStack {
            SkyBackground().ignoresSafeArea()
            FittingScroll {
                VStack(spacing: FledgeTheme.Space.xl) {
                    Spacer(minLength: FledgeTheme.Space.l)
                    if opened {
                        VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
                            Text("From January").fledgeEyebrow()
                            Text(resolution.letter)
                                .font(.system(.title3, design: .serif))
                                .foregroundStyle(FledgeTheme.Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if !resolution.why.isEmpty {
                                Divider()
                                Text("Why it mattered: \(resolution.why)")
                                    .font(.subheadline.italic())
                                    .foregroundStyle(FledgeTheme.Palette.ink2)
                            }
                        }
                        .padding(FledgeTheme.Space.xl)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fledgeCard(tint: FledgeTheme.Palette.gold)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
                    } else {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 96))
                            .foregroundStyle(FledgeTheme.Palette.gold)
                            .accessibilityHidden(true)
                        Text("A letter about \u{201C}\(resolution.text)\u{201D}")
                            .font(FledgeTheme.Typeface.title)
                            .foregroundStyle(FledgeTheme.Palette.ink)
                            .multilineTextAlignment(.center)
                    }
                    Spacer(minLength: FledgeTheme.Space.l)
                    PrimaryActionButton(title: opened ? "Close" : "Open it", systemImage: opened ? "checkmark" : "envelope.open.fill") {
                        if opened {
                            dismiss()
                        } else {
                            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.8)) {
                                opened = true
                            }
                        }
                    }
                    .padding(.bottom, FledgeTheme.Space.l)
                }
                .padding(.horizontal, FledgeTheme.screenMargin)
                .frame(maxWidth: NestLayout.readableWidth)
            }
        }
        .sensoryFeedback(.success, trigger: opened)
    }
}
