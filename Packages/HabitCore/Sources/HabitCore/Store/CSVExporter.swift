import Foundation

/// Plain CSV of every habit's day logs, for Settings › Export (Pro). Raw Health values are included
/// because the file is created on device and shared only by the user.
public enum CSVExporter {
    public static let header = "date,habit,state,status,value,unit,completed_by"

    public struct Row: Sendable, Equatable {
        public let day: String
        public let habit: String
        public let state: String
        public let status: String
        public let value: Double
        public let unit: String
        public let completedBy: String

        public init(day: String, habit: String, state: String, status: String, value: Double, unit: String, completedBy: String) {
            self.day = day
            self.habit = habit
            self.state = state
            self.status = status
            self.value = value
            self.unit = unit
            self.completedBy = completedBy
        }
    }

    public static func rows(from habits: [Habit]) -> [Row] {
        habits.flatMap { habit in
            (habit.logs ?? []).map { log in
                Row(
                    day: log.dayKey, habit: habit.name, state: habit.stateRaw, status: log.statusRaw,
                    value: log.value, unit: habit.unit, completedBy: log.completedByRaw ?? ""
                )
            }
        }
        .sorted { ($0.day, $0.habit) < ($1.day, $1.habit) }
    }

    public static func csv(_ rows: [Row]) -> String {
        let lines = rows.map { row in
            [row.day, escape(row.habit), row.state, row.status, number(row.value), escape(row.unit), row.completedBy]
                .joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\n") + "\n"
    }

    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
