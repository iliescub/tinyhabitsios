import SwiftUI
import HabitCore
import FledgeUI

/// Form for a `HabitDraft`, shared by Add (configure step) and Edit (docs/DESIGN.md §6.3, v2 in UX-10):
/// a live preview of the card on top, a large goal control, and the icon picker in its own sheet.
struct HabitEditorView: View {
    @Binding var draft: HabitDraft
    /// HEAD-1: the last 30 days from Apple Health, shown when adding a Health habit.
    var headStart: HeadStartState = .none
    @State private var pickingIcon = false

    var body: some View {
        Form {
            Section {
                HabitPreviewCard(draft: draft)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Preview")
            }

            switch headStart {
            case .none:
                EmptyView()
            case .loading:
                Section("Your last 30 days") {
                    Label("Looking at Apple Health…", systemImage: "heart.text.square")
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
            case .values(let values):
                Section {
                    HeadStartView(values: values, draft: $draft)
                } header: {
                    Text("Your last 30 days")
                } footer: {
                    Text("Read on this \(DeviceInfo.name) from Apple Health. Graduation still counts from the day you add the habit.")
                }
            }

            Section {
                TextField("Name", text: $draft.name)
                    .textInputAutocapitalization(.sentences)
                Button { pickingIcon = true } label: {
                    LabeledContent("Icon") {
                        IconSquare(symbol: draft.symbol, color: FledgeTheme.habitColor(draft.colorKey))
                    }
                }
                .accessibilityLabel(Text("Icon"))
                .accessibilityHint(Text("Choose the habit's icon"))
                .tint(FledgeTheme.Palette.ink)
                ColorRow(selection: $draft.colorKey)
            } footer: {
                if draft.problem == .nameTooLong {
                    Text("Keep it under \(HabitDraft.maxNameLength) characters so it fits on widgets.")
                }
            }

            Section {
                if draft.source.isAuto {
                    HStack {
                        Text("Completes from")
                        Spacer()
                        Image(systemName: "heart.fill").foregroundStyle(FledgeTheme.Palette.sky)
                        Text("Apple Health").foregroundStyle(FledgeTheme.Palette.ink2)
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    Picker("Unit", selection: $draft.unit) {
                        ForEach(FledgeTheme.manualUnits, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: draft.unit) { _, unit in
                        draft.target = TargetSteps.clamp(draft.target, unit: unit)
                    }
                }
                GoalControl(target: $draft.target, unit: draft.unit)
            } header: {
                Text("Daily goal")
            }

            Section {
                Picker("How often", selection: dailyBinding) {
                    Text("Every day").tag(true)
                    Text("Some days").tag(false)
                }
                .pickerStyle(.segmented)
                if draft.perWeek < 7 {
                    Stepper("\(draft.perWeek) \(draft.perWeek == 1 ? "day" : "days") a week", value: $draft.perWeek, in: 1...6)
                }
            } header: {
                Text("How often")
            } footer: {
                Text(draft.perWeek < 7
                     ? "Rest whenever you like, as long as you reach \(draft.perWeek) days in the week."
                     : "You get \(RestDayPolicy.freePassesPerMonth) rest days a month without breaking your streak.")
            }

            Section {
                Toggle("Reminder", isOn: reminderBinding)
                    .tint(FledgeTheme.Palette.meadow)
                if draft.reminderMinutes != nil {
                    DatePicker("Time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text("Sent only if the habit isn't done yet.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(FledgeTheme.Palette.cloud)
        // Section headers and footers use the secondary style: ink2 meets AA on cloud; the system grey (≈ 3.3 : 1) doesn't.
        .foregroundStyle(FledgeTheme.Palette.ink, FledgeTheme.Palette.ink2)
        .sheet(isPresented: $pickingIcon) {
            IconPickerSheet(symbol: $draft.symbol, color: FledgeTheme.habitColor(draft.colorKey))
                .presentationDetents([.medium, .large])
        }
    }

    private var dailyBinding: Binding<Bool> {
        Binding(get: { draft.perWeek == 7 }, set: { draft.perWeek = $0 ? 7 : 3 })
    }

    private var reminderBinding: Binding<Bool> {
        Binding(get: { draft.reminderMinutes != nil }, set: { draft.reminderMinutes = $0 ? (draft.reminderMinutes ?? 19 * 60) : nil })
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let minutes = draft.reminderMinutes ?? 19 * 60
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft.reminderMinutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

/// The card as it will look on Today, two thirds of the way to the goal, updating as the form changes.
struct HabitPreviewCard: View {
    let draft: HabitDraft

    var body: some View {
        let today = DayKey(.now)
        let card = HabitCardModel(
            name: draft.trimmedName.isEmpty ? "New habit" : draft.trimmedName,
            symbol: draft.symbol, colorKey: draft.colorKey, source: draft.source,
            target: draft.target, unit: draft.unit, cadence: Cadence(perWeek: draft.perWeek),
            startedOn: today, today: today,
            todayValue: draft.target > 1 ? (draft.target * 2 / 3).rounded() : 0,
            todayStatus: .pending, todayCompletedBy: nil, history: []
        )
        VStack(alignment: .leading, spacing: FledgeTheme.Space.s) {
            HStack(spacing: FledgeTheme.Space.l) {
                HabitRing(
                    fraction: card.progress.fraction, status: .pending,
                    color: FledgeTheme.habitColor(draft.colorKey), symbol: draft.symbol
                )
                VStack(alignment: .leading, spacing: FledgeTheme.Space.xs) {
                    Text(card.name)
                        .font(.headline)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                        .lineLimit(1)
                    ValueLine(model: card)
                    Text(draft.source.isAuto ? "Fills in from Apple Health" : "Tap the ring to log")
                        .font(FledgeTheme.Typeface.meta)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
                Spacer(minLength: 0)
            }
            .padding(FledgeTheme.Space.l)
            .fledgeCard()
        }
        .padding(.vertical, FledgeTheme.Space.xs)
        .animation(.snappy, value: draft)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Preview: \(card.name), \(card.valueText)"))
    }
}

/// HEAD-1: the user's own last 30 days for this habit, what that means, and a goal to start from.
struct HeadStartView: View {
    let values: [Double]
    @Binding var draft: HabitDraft

    var body: some View {
        let baseline = HealthBaseline(
            values: values, target: draft.target,
            step: TargetSteps.step(for: draft.unit), range: TargetSteps.range(for: draft.unit)
        )
        let color = FledgeTheme.habitColor(draft.colorKey)
        VStack(alignment: .leading, spacing: FledgeTheme.Space.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(amount(baseline.average))
                        .font(FledgeTheme.Typeface.metric)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Text("\(draft.unit) on an average day")
                        .font(.caption)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(baseline.daysMet) of \(values.count)")
                        .font(FledgeTheme.Typeface.metric)
                        .foregroundStyle(FledgeTheme.Palette.ink)
                    Text("days at \(amount(draft.target)) \(draft.unit)")
                        .font(.caption)
                        .foregroundStyle(FledgeTheme.Palette.ink2)
                }
            }
            .accessibilityElement(children: .combine)

            // One bar per day, height by value, in the habit colour when the goal was met.
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(value >= draft.target ? color : FledgeTheme.Palette.ink2.opacity(0.25))
                        .frame(height: max(3, 34 * min(value / max(draft.target * 1.5, 1), 1)))
                }
            }
            .frame(height: 34, alignment: .bottom)
            .accessibilityHidden(true)

            Text(message(baseline))
                .font(.subheadline)
                .foregroundStyle(FledgeTheme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let suggested = baseline.suggestedTarget {
                Button {
                    withAnimation(.snappy) { draft.target = suggested }
                } label: {
                    // Own capsule: the system bordered style clipped this label in the accessibility audit.
                    Label(
                        baseline.verdict == .alreadyHabit ? "Aim for \(amount(suggested)) \(draft.unit)" : "Start at \(amount(suggested)) \(draft.unit)",
                        systemImage: baseline.verdict == .alreadyHabit ? "arrow.up.right" : "leaf"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FledgeTheme.Palette.ink)
                    .padding(.horizontal, FledgeTheme.Space.m)
                    .padding(.vertical, FledgeTheme.Space.s)
                    .frame(minHeight: 44)
                    .background(FledgeTheme.Palette.ink.opacity(0.08), in: .capsule)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, FledgeTheme.Space.xs)
        .animation(.snappy, value: draft.target)
    }

    private func message(_ baseline: HealthBaseline) -> String {
        let name = draft.trimmedName.isEmpty ? "This" : draft.trimmedName
        switch baseline.verdict {
        case .notEnoughData:
            return "There's not much \(name) data in Apple Health yet. Fledge fills it in from today."
        case .alreadyHabit:
            return "\(name) is already a habit for you. Aim a little higher, or pick something new and let this one be."
        case .withinReach:
            return "Within reach: you got there on \(baseline.daysMet) of the last 30 days. Keep the goal."
        case .startSmaller:
            return "You usually reach about \(amount(baseline.average)) \(draft.unit). Start just above that: small wins stick."
        }
    }

    private func amount(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(value < 10 ? 0...1 : 0...0)))
    }
}

/// The goal as a large rounded number with − and + (UX-10). Adjustable for VoiceOver.
struct GoalControl: View {
    @Binding var target: Double
    let unit: String

    private var range: ClosedRange<Double> { TargetSteps.range(for: unit) }
    private var step: Double { TargetSteps.step(for: unit) }

    var body: some View {
        HStack {
            stepButton("minus", enabled: target > range.lowerBound) { change(by: -step) }
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text(amountText)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit())
                    .foregroundStyle(FledgeTheme.Palette.ink)
                    .contentTransition(.numericText(value: target))
                Text(unitText)
                    .font(.subheadline)
                    .foregroundStyle(FledgeTheme.Palette.ink2)
            }
            Spacer(minLength: 0)
            stepButton("plus", enabled: target < range.upperBound) { change(by: step) }
        }
        .padding(.vertical, FledgeTheme.Space.s)
        .accessibilityElement()
        .accessibilityLabel(Text("Daily goal"))
        .accessibilityValue(Text("\(amountText) \(unitText)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(by: step)
            case .decrement: change(by: -step)
            @unknown default: break
            }
        }
    }

    private var amountText: String {
        unit == "times" && target == 1 ? "Once" : target.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var unitText: String {
        unit == "times" && target == 1 ? "a day" : "\(unit) a day"
    }

    private func change(by delta: Double) {
        withAnimation(.snappy) {
            target = TargetSteps.clamp(target + delta, unit: unit)
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 44, height: 44)
                .background(FledgeTheme.Palette.hairline.opacity(0.6), in: .circle)
                .foregroundStyle(FledgeTheme.Palette.ink)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .sensoryFeedback(.selection, trigger: target)
        .accessibilityLabel(Text(symbol == "plus" ? "Increase goal" : "Decrease goal"))
    }
}

/// The eight habit colours as swatches.
struct ColorRow: View {
    @Binding var selection: String

    var body: some View {
        HStack {
            ForEach(FledgeTheme.habitColorKeys, id: \.self) { key in
                Button { selection = key } label: {
                    Circle()
                        .fill(FledgeTheme.habitColor(key))
                        .frame(width: 28, height: 28)
                        .overlay {
                            if key == selection {
                                Circle().strokeBorder(FledgeTheme.Palette.ink, lineWidth: 2).padding(-4)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(FledgeTheme.habitColorName(key)))
                .accessibilityAddTraits(key == selection ? .isSelected : [])
            }
        }
    }
}

/// Every habit symbol in a grid, in the habit's colour.
struct IconPickerSheet: View {
    @Binding var symbol: String
    let color: Color
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: FledgeTheme.Space.m)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: FledgeTheme.Space.m) {
                    ForEach(FledgeTheme.habitSymbols, id: \.self) { item in
                        Button {
                            symbol = item
                            dismiss()
                        } label: {
                            Image(systemName: item)
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .frame(width: 52, height: 52)
                                .foregroundStyle(item == symbol ? Color.white : color)
                                .background(item == symbol ? color : color.opacity(0.12), in: .rect(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.replacingOccurrences(of: ".", with: " "))
                        .accessibilityAddTraits(item == symbol ? .isSelected : [])
                    }
                }
                .padding(FledgeTheme.screenMargin)
            }
            .background(FledgeTheme.Palette.cloud)
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Sensible stepper ranges per unit.
enum TargetSteps {
    static func step(for unit: String) -> Double {
        switch unit {
        case "steps": 500
        case "min", "pages": 5
        case "L", "km", "h": 0.5
        default: 1
        }
    }

    static func range(for unit: String) -> ClosedRange<Double> {
        switch unit {
        case "steps": 500...50_000
        case "min": 5...240
        case "pages": 5...200
        case "L": 0.5...5
        case "km": 0.5...50
        case "h": 4...12
        case "hours": 1...16
        case "workout": 1...5
        case "glasses": 1...15
        default: 1...20
        }
    }

    static func clamp(_ value: Double, unit: String) -> Double {
        let range = range(for: unit)
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
