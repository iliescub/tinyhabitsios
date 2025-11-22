import Foundation

struct MotivationProvider {
    static func dailyQuote() -> String {
        let quotes = [
            "Small steps, every day.",
            "Consistency beats intensity.",
            "Done is better than perfect.",
            "Tiny wins compound over time.",
            "Show up for your future self."
        ]
        let dayIndex = Calendar.current.component(.day, from: Date())
        return quotes[dayIndex % quotes.count]
    }
}
