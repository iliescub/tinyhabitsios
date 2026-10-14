import Foundation
import HabitCore

/// How templates look in Add and onboarding (UX-9): each has its own colour, and a short goal line.
public enum TemplateStyle {
    /// A fixed colour per Health source, so Sleep is always lilac and Walk always dawn; manual templates by name.
    public static func colorKey(for template: Pack.Template) -> String {
        switch template.source {
        case .steps: return "dawn"
        case .exerciseMinutes: return "rose"
        case .workout: return "teal"
        case .standHours: return "slate"
        case .mindfulMinutes: return "meadow"
        case .sleep: return "lilac"
        case .water: return "sky"
        case .daylight: return "gold"
        default:
            let manual = ["sky", "meadow", "lilac", "teal", "rose", "gold", "dawn", "slate"]
            let index = template.name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
            return manual[index % manual.count]
        }
    }

    /// The template's own colour unless another habit in the nest already uses it; then the slot's default,
    /// then the first colour nobody uses. Keeps the three habits easy to tell apart.
    public static func preferredColorKey(for template: Pack.Template, taken: Set<String>, slot: Int) -> String {
        let own = colorKey(for: template)
        if !taken.contains(own) { return own }
        let slotDefault = FledgeTheme.defaultColorKey(forSlot: slot)
        if !taken.contains(slotDefault) { return slotDefault }
        return FledgeTheme.habitColorKeys.first { !taken.contains($0) } ?? own
    }

    /// "6,000 steps a day", "Once a day", "1 workout · 3× a week".
    public static func targetText(for template: Pack.Template, locale: Locale = .current) -> String {
        let amount = template.target.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
        let isOnce = template.target <= 1 && template.unit == "times"
        if let perWeek = template.perWeek, perWeek < 7 {
            return "\(isOnce ? "Once" : "\(amount) \(template.unit)") · \(perWeek)× a week"
        }
        return isOnce ? "Once a day" : "\(amount) \(template.unit) a day"
    }
}
