import Foundation

struct HabitProgress {
    let status: HabitStatus
    let current: Int
    let target: Int
    let completion: Double

    var percentString: String {
        let percent = Int(completion * 100)
        return "\(percent)%"
    }
}
