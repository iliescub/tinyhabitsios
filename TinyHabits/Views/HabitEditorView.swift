import SwiftUI
import HabitCore
import FledgeUI

/// Form for a `HabitDraft`, shared by Add (configure step) and Edit (docs/DESIGN.md §6.3).
struct HabitEditorView: View {
    @Binding var draft: HabitDraft

    private let symbolColumns = Array(repeating: GridItem(.flexible(), spacing: FledgeTheme.Space.s), count: 6)

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draft.name)
                    .textInputAutocapitalization(.sentences)
            } footer: {
                if draft.problem == .nameTooLong {
                    Text("Keep it under \(HabitDraft.maxNameLength) characters so it fits on widgets.")
                }
            }

            Section("Icon and colour") {
                LazyVGrid(columns: symbolColumns, spacing: FledgeTheme.Space.s) {
                    ForEach(FledgeTheme.habitSymbols, id: \.self) { symbol in
                        Button { draft.symbol = symbol } label: {
                            Image(systemName: symbol)
                                .font(.title3)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .foregroundStyle(symbol == draft.symbol ? Color.white : FledgeTheme.habitColor(draft.colorKey))
                                .background(
                                    symbol == draft.symbol ? FledgeTheme.habitColor(draft.colorKey) : FledgeTheme.habitColor(draft.colorKey).opacity(0.12),
                                    in: .rect(cornerRadius: 10)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                        .accessibilityAddTraits(symbol == draft.symbol ? .isSelected : [])
                    }
                }
                .padding(.vertical, FledgeTheme.Space.xs)

                HStack {
                    ForEach(FledgeTheme.habitColorKeys, id: \.self) { key in
                        Button { draft.colorKey = key } label: {
                            Circle()
                                .fill(FledgeTheme.habitColor(key))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if key == draft.colorKey {
                                        Circle().strokeBorder(FledgeTheme.Palette.ink, lineWidth: 2).padding(-4)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(key)
                        .accessibilityAddTraits(key == draft.colorKey ? .isSelected : [])
                    }
                }
                .padding(.vertical, FledgeTheme.Space.xs)
            }

            Section {
                if draft.source.isAuto {
                    LabeledContent("Completes from", value: "Apple Health")
                } else {
                    Picker("Unit", selection: $draft.unit) {
                        ForEach(FledgeTheme.manualUnits, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: draft.unit) { _, unit in
                        draft.target = TargetSteps.clamp(draft.target, unit: unit)
                    }
                }
                Stepper(value: $draft.target, in: TargetSteps.range(for: draft.unit), step: TargetSteps.step(for: draft.unit)) {
                    Text(goalText).monospacedDigit()
                }
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
                if draft.reminderMinutes != nil {
                    DatePicker("Time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text("Sent only if the habit isn't done yet.")
            }
        }
    }

    private var goalText: String {
        let amount = draft.target.formatted(.number.precision(.fractionLength(0...2)))
        if draft.unit == "times" {
            return draft.target == 1 ? "Once" : "\(amount) times"
        }
        return "\(amount) \(draft.unit)"
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
